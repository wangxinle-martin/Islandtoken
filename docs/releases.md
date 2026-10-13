# Version and releases

`VERSION` is the release version source and `BUILD_NUMBER` is the monotonically increasing build number. App metadata, sidebar and update settings display them as `VERSION(BUILD_NUMBER)`, while update discovery compares only `VERSION`.

The updater only considers stable `islandtoken-vMAJOR.MINOR.PATCH` releases in `wangxinle-martin/Islandtoken`, compares numeric components, and selects the exact DMG and SHA-256 sidecar for the host architecture. Automatic checking runs every five minutes; the launch check is configurable. New versions show a notice once per version per app session.

Version 0.3.3 is a one-time bridge published with identical assets in both `taishanrou/CodexWorkspaces` and the previous standalone repository: 0.3.2 clients still checking the former can migrate. Version 0.4.1 and later use `wangxinle-martin/Islandtoken`.

Starting with 0.3.0, **Download and Install** downloads both assets, verifies file size, SHA-256, the DMG, bundle identifier, version, architecture, and code signature, then stages the app beside the current installation. A helper waits for the old process and its single-instance lock to exit, atomically swaps the bundles, relaunches the new version, and rolls back if launch acknowledgement fails. The installation directory must be writable; preferences and application-support data are not replaced. Versions before 0.3.0 require one final manual DMG installation before this automatic flow is available.

For private repositories, install GitHub CLI and run `gh auth login` using an account with repository access. Automatic installation tries the GitHub asset URL first and falls back to `gh release download`; no personal token is embedded in the app.

Release steps:
1. Update `VERSION`, increment `BUILD_NUMBER`, and update `docs/release-notes.md`.
2. Run `script/test.sh`, build the app, bundle the collector, and run `script/package_release.sh`.
3. Commit and push the project changes.
4. Sync the committed project to `wangxinle-martin/Islandtoken`, then create and push the matching `islandtoken-v...` tag there. Publish the verified DMG and SHA-256 sidecar to that repository with `gh release create --repo wangxinle-martin/Islandtoken --verify-tag --latest`.

The parent monorepo workflow uses a repository-scoped token and does not publish to the private updater repository. Artifacts are ad-hoc signed and not notarized. No ZIP is generated. Main-branch code and published releases are separate: only a successfully published Release is discoverable by the updater.
