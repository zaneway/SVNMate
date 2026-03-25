# Settings Design

## Goal

Add an application-level settings system for:

- configurable SVN binary override path
- configurable command timeouts
- configurable application accent color
- configurable SVN file status colors

The settings must be persisted locally, applied immediately to new operations, and exposed through a standard macOS Settings window.

## Scope

This iteration covers:

- global application settings only
- runtime settings propagation
- local persistence
- settings UI
- theme/status color integration in the main UI

This iteration does not cover:

- per-repository settings
- credential settings
- settings import/export
- profile-based theming
- changing timeouts for commands that are already running

## Architecture

### AppSettings

`AppSettings` is the single source of truth for persisted application configuration.

It contains:

- `svnBinaryPathOverride`
- `timeouts`
  - `defaultOperationSeconds`
  - `networkOperationSeconds`
  - `checkoutOperationSeconds`
  - `logOperationSeconds`
- `theme`
  - `accentColor`
  - `statusColors`

### SettingsStore

`SettingsStore` persists a single encoded `AppSettings` blob in `UserDefaults`.

Responsibilities:

- load settings with defaults fallback
- save settings atomically
- restore defaults

### SettingsController

`SettingsController` is the runtime bridge between persistence, services, and UI.

Responsibilities:

- publish the current `AppSettings`
- validate user input before saving
- expose a derived `AppTheme`
- apply updates immediately to future commands and UI rendering

`SettingsController` is application-global because the configuration scope is application-global.

## Services Integration

### SVNBinaryResolver

Resolver order becomes:

1. environment variable override (`SVN_BINARY_PATH`)
2. settings override path
3. built-in auto-detect paths

If the configured settings path is invalid, resolution fails with an explicit error instead of silently falling back.

### SVNService

`SVNService` no longer relies on hardcoded timeout constants. It reads timeout values from the current settings when each operation is started.

This means:

- settings changes affect future commands immediately
- in-flight commands keep the timeout they started with

## Theme Integration

### AppTheme

`AppTheme` is a derived, UI-facing view of the settings.

It exposes:

- `accentColor`
- `color(for status: FileStatus)`

Views should use `AppTheme` instead of directly hardcoding `Color.blue`, `Color.green`, `Color.red`, or `Color.accentColor` for configurable paths.

### Color Model

Accent color and status colors are persisted as palette-backed tokens.

Benefits:

- stable persistence
- deterministic appearance
- reduced validation complexity
- lower risk of unreadable low-contrast combinations

## Settings UI

The settings window contains three sections:

1. `General`
   - SVN binary override path
   - browse button
   - reset-to-auto-detect action
   - effective resolved binary preview

2. `Timeouts`
   - default operation timeout
   - network operation timeout
   - checkout timeout
   - log timeout
   - bounded numeric editing

3. `Appearance`
   - application accent color
   - per-status color pickers
   - restore defaults

Settings are saved immediately after valid edits. Invalid input stays visible with inline validation feedback.

## Validation

### Binary Path

- empty value means auto-detect
- non-empty value must exist and be executable

### Timeouts

- all values must be positive integers
- bounded ranges are enforced

Recommended ranges:

- default: `5...600`
- network: `30...3600`
- checkout: `60...7200`
- log: `10...1800`

## UI Entry Points

- standard macOS `Settings` scene
- optional `Settings...` entry in the sidebar add menu

## Migration and Compatibility

- if no persisted settings exist, defaults reproduce the current application behavior
- existing repositories and repository storage remain unchanged
- existing services continue to work, but now read settings dynamically

## Implementation Order

1. add settings model and persistence
2. add settings controller and theme environment
3. integrate resolver and service timeout lookup
4. add settings window and menu entry
5. replace primary configurable color hardcodes in the main UI
6. compile and verify
