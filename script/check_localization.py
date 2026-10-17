#!/usr/bin/env python3
"""Checks static UI-localization keys and the bilingual release-note contract."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"
COMPATIBILITY = SOURCES / "IsLandToken" / "CodexBarPopup" / "Compatibility.swift"
RELEASE_NOTES = ROOT / "docs" / "release-notes.md"
CURRENT_RELEASE_NOTES = {
    "中文": ROOT / "Sources" / "IsLandToken" / "Resources" / "current-release-notes-zh.md",
    "English": ROOT / "Sources" / "IsLandToken" / "Resources" / "current-release-notes-en.md",
}


def function_dictionary(source: str, function: str) -> str:
    function_start = source.index(f"func {function}(")
    dictionary_start = source.index("translated =", function_start)
    dictionary_end = source.index("][key] ?? key", dictionary_start)
    return source[dictionary_start:dictionary_end]


def quoted_keys(source: str) -> set[str]:
    return set(re.findall(r'"((?:\\.|[^"\\])*)"\s*:', source))


def static_calls(source: str, function: str) -> set[str]:
    return set(re.findall(rf'\b{function}\(\s*"((?:\\.|[^"\\])*)"', source))


def contains_han(value: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", value))


compatibility = COMPATIBILITY.read_text(encoding="utf-8")
all_source = "\n".join(path.read_text(encoding="utf-8") for path in SOURCES.rglob("*.swift"))

t_keys = quoted_keys(function_dictionary(compatibility, "T"))
l_keys = quoted_keys(function_dictionary(compatibility, "L"))
t_calls = static_calls(all_source, "T")
l_calls = static_calls(all_source, "L")

missing_t = sorted(key for key in t_calls if contains_han(key) and key not in t_keys)
missing_l = sorted(key for key in l_calls if key not in l_keys)

if missing_t or missing_l:
    if missing_t:
        print("Missing T() translations:", *missing_t, sep="\n  - ")
    if missing_l:
        print("Missing L() translations:", *missing_l, sep="\n  - ")
    sys.exit(1)

release_notes = RELEASE_NOTES.read_text(encoding="utf-8")
missing_sections = [
    language for language in CURRENT_RELEASE_NOTES if f"### {language}" not in release_notes
]
empty_current_notes = [
    language
    for language, path in CURRENT_RELEASE_NOTES.items()
    if not path.read_text(encoding="utf-8").strip()
]

if missing_sections or empty_current_notes:
    if missing_sections:
        print("Missing bilingual release-note sections:", *missing_sections, sep="\n  - ")
    if empty_current_notes:
        print("Empty current release-note resources:", *empty_current_notes, sep="\n  - ")
    sys.exit(1)

print("Localization key and bilingual release-note coverage passed")
