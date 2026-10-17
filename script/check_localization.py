#!/usr/bin/env python3
"""Fails when a static UI-localization key is not present in Compatibility.swift."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"
COMPATIBILITY = SOURCES / "IsLandToken" / "CodexBarPopup" / "Compatibility.swift"


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

print("Localization key coverage passed")
