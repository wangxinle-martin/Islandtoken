# Version and releases

`VERSION` is the build version source. App metadata, sidebar and update settings read the built bundle version.

The updater only considers stable `islandtoken-vMAJOR.MINOR.PATCH` releases in `taishanrou/CodexWorkspaces`, compares numeric components, and selects DMG assets for the host architecture. Automatic checking runs on launch and is configurable. Downloads open in the browser; installation is manual.

For private repositories, install GitHub CLI and run `gh auth login` using an account with repository access. No personal token is embedded in the app. Browser downloads also require repository access.

Release steps:
1. Update `VERSION` and `docs/release-notes.md`.
2. Run `script/test.sh`, build the app, bundle the collector, and run `script/package_release.sh`.
3. Commit and push the project changes.
4. Create and push the corresponding `islandtoken-v...` tag. The root GitHub Actions workflow builds, tests and publishes the DMG with a SHA-256 sidecar using its scoped repository token.

Artifacts are ad-hoc signed and not notarized. No ZIP is generated. GitHub Actions must be enabled on the repository. Main-branch code and published releases are separate: only a successfully published Release is discoverable by the updater.
