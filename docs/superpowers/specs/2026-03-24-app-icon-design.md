## Summary

This change adds a fixed macOS app icon for SVNMate and ensures the icon is bundled into the `.app` and `.dmg` outputs without changing the existing packaging pipeline.

## Goals

- Give SVNMate a recognizable Dock and Finder icon
- Keep the build result deterministic
- Reuse the existing `xcodegen + xcodebuild + package_dmg.sh` pipeline

## Non-Goals

- Dynamic icon generation during packaging
- Multiple icon themes or seasonal variants
- Custom DMG volume icon

## Design

### Asset Layout

The app icon is stored as a standard asset catalog:

- `SVNMate/Sources/Assets.xcassets/Contents.json`
- `SVNMate/Sources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `SVNMate/Sources/Assets.xcassets/AppIcon.appiconset/*.png`

The project already uses `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, so placing the asset catalog under `SVNMate/Sources` keeps it inside the existing XcodeGen target source path.

### Visual Direction

The icon follows a product-oriented macOS tool style:

- rounded square background
- blue-green gradient base
- warm accent nodes for contrast
- abstract version-control branch lines
- document silhouette to communicate working-copy and file operations

This avoids a text-heavy logo and stays recognizable at small sizes.

### Source Artifact

An editable source file is kept at:

- `design/app-icon-source.svg`

It is not used by the build. The build only consumes the generated PNG files in `AppIcon.appiconset`.

## Validation

Validation consists of:

1. `xcodebuild` Release build succeeds with the asset catalog
2. the generated `.app` contains the new icon
3. the internal test DMG is rebuilt successfully

## Risks

- Finder and Dock may cache older icons after replacing the app
- if the asset catalog is not picked up by XcodeGen target inputs, the icon will silently remain unchanged
