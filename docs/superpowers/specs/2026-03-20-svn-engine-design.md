# SVN Engine Refactor Design

## Goal

Stabilize the first usable iteration of the macOS SVN client by separating command execution from UI state, switching fragile text parsing to XML-based parsing, and wiring file selection into commit execution.

## Scope

- Split the current monolithic `SVNService` responsibilities into:
  - `SVNBinaryResolver`
  - `SVNCommandRunner`
  - `SVNXMLParser`
  - `SVNService` facade
- Move models and repository persistence out of `AppState`
- Parse `svn info` and `svn status` via `--xml`
- Build a stable file tree that synthesizes missing parent directories
- Replace transient `UUID` selection with path-based selection
- Pass selected paths into `svn commit`

## Architecture

### `SVNBinaryResolver`

Resolves the `svn` executable from the following sources in order:

1. `SVN_BINARY_PATH` environment override
2. `SVNMate.svnBinaryPath` stored in `UserDefaults`
3. Known system paths:
   - `/usr/bin/svn`
   - `/opt/homebrew/bin/svn`
   - `/usr/local/bin/svn`

This keeps the resolution deterministic and avoids shell-dependent lookup.

### `SVNCommandRunner`

Owns command execution and returns a structured `SVNCommandResult`:

- executable path
- final argv
- stdout
- stderr
- exit status

The runner enforces timeout and cancellation via `Process.terminate()`. `SVNService` remains the user-facing facade for feature operations.

### `SVNXMLParser`

Parses:

- `svn info --xml`
- `svn status --xml`

The parser converts XML output into app models instead of relying on column offsets from human-readable text output.

### `SVNService`

High-level API used by view models:

- `info`
- `status`
- `update`
- `commit`
- `checkout`
- `diff`
- `log`
- `cleanup`
- `resolve`

It combines the resolver, runner, and parser while keeping UI code unaware of process details.

## Data Model Changes

- `Repository.id` becomes path-based for stable selection and persistence
- `FileNode.id` becomes relative path-based
- `FileNode` tracks commit eligibility
- File tree nodes are synthesized for missing parent directories so nested modified files always render in a navigable tree

## Commit Selection Behavior

- File selection is path-based, not UUID-based
- Selected changed files are passed directly to `svn commit`
- If no file is selected, commit remains repository-wide for backward compatibility
- Non-committable statuses such as unversioned and ignored are excluded from selection

## Error Handling

- Binary resolution failure returns a user-facing `SVNError`
- Non-zero exit code includes stderr first, then stdout fallback
- Timeout and cancellation produce explicit errors instead of hanging the UI

## Risks

- `svn` XML payloads vary slightly across versions; parser must tolerate missing optional elements
- Commiting selected files only is safe, but mixed directory/file selections may need future normalization
- Authentication UX is not solved in this refactor; this iteration only prepares the execution boundary for that work

## Validation Plan

- Build the app after refactor
- Verify repository open, refresh, diff, update, and selected-file commit still work
- Check nested changed files appear under synthesized directories
