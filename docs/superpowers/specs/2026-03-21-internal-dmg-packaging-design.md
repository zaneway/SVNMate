# Internal DMG Packaging Design

## Goal

Provide a repeatable way to package SVNMate as an internal-test macOS DMG.

The output should be:

- a Release-built `SVNMate.app`
- a drag-install DMG containing `SVNMate.app`
- an `Applications` shortcut inside the DMG

This packaging flow targets internal testing only. It does not include signing, notarization, or stapling.

## Scope

This iteration includes:

- project generation when `SVNMate.xcodeproj` is absent
- Release app build using `xcodebuild`
- DMG staging layout
- compressed DMG generation using `hdiutil`
- documentation updates

This iteration does not include:

- notarization
- Developer ID signing
- CI publishing
- auto-updates
- custom DMG background artwork

## Build Strategy

For internal testing, use the lighter Release build path instead of the full archive/export pipeline.

Build command shape:

- `xcodegen generate` when needed
- `xcodebuild -project SVNMate.xcodeproj -scheme SVNMate -configuration Release -derivedDataPath build/DerivedData build`

The produced app is copied from:

- `build/DerivedData/Build/Products/Release/SVNMate.app`

This is simpler than archive/export while still producing a valid `.app` bundle suitable for internal distribution.

## Packaging Strategy

1. create a temporary staging directory
2. copy `SVNMate.app` into the staging directory
3. create an `Applications` symlink inside the staging directory
4. run `hdiutil create` to build a compressed DMG
5. place final artifacts in `dist/`

Final artifact layout:

- `dist/SVNMate.app`
- `dist/SVNMate-macOS.dmg`

## Script

Add a repository-local script:

- `scripts/package_dmg.sh`

Responsibilities:

- verify required tools exist
- optionally run `xcodegen generate`
- run the Release build
- prepare the DMG staging directory
- generate the final DMG
- print final artifact paths

The script should fail fast and surface actionable errors when tools or build products are missing.

## Repository Hygiene

Generated packaging output should not be committed.

Ignore:

- `build/`
- `dist/`

## Documentation

Update the install/deploy manual with:

- required tools
- single-command packaging flow
- output paths
- internal-test caveats for unsigned DMGs

## Validation

Validation for this iteration:

- script runs successfully end to end on the local machine
- `.app` exists in `dist/`
- `.dmg` exists in `dist/`
- DMG contains `SVNMate.app` and `Applications` link
