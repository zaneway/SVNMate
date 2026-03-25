## Summary

This change adds application localization for English and Simplified Chinese, with a default language strategy of "follow system language" and a manual override in Settings.

## Goals

- Support `zh-Hans` and `en`
- Default to system language when supported
- Fall back to Simplified Chinese for unsupported system languages
- Allow runtime override in Settings without restarting the app
- Localize common settings, UI labels, summaries, and common error text

## Non-Goals

- Full localization of raw SVN stderr output
- Support for additional languages in this iteration
- Typed `.xcstrings` catalog migration

## Design

### Language Resolution

`AppSettings` stores a new `preferredLanguage` field with three values:

- `system`
- `zh-Hans`
- `en`

At runtime, `LocalizationController` resolves the effective language:

- explicit `zh-Hans` or `en` wins
- `system` maps system `zh*` to `zh-Hans`
- `system` maps system `en*` to `en`
- all other system languages fall back to `zh-Hans`

### Resource Layout

Localized resources are stored under:

- `SVNMate/Sources/zh-Hans.lproj/Localizable.strings`
- `SVNMate/Sources/en.lproj/Localizable.strings`

`CFBundleDevelopmentRegion` is set to `zh-Hans`.

### Runtime Model

The app injects both:

- `Locale`
- a custom `AppLocalizer`

`Locale` drives SwiftUI string-key localization.
`AppLocalizer` handles dynamic strings, formatted counts, and model-layer display text.

### Scope

This iteration localizes:

- main window shell
- settings window
- menu bar extra
- checkout sheet
- repository detail primary labels and actions
- file status labels
- tree conflict display labels
- common settings and command errors

## Validation

Validation requires:

1. successful build with localized resources
2. Settings language override updates visible UI immediately
3. unsupported system language falls back to Simplified Chinese

## Risks

- some macOS window or scene titles may not refresh instantly on language change
- raw SVN stderr output remains server-provided and may not match app language
