## Overview

This spec evolves the `Files` pane from an SVN status list into a working-copy browser.

The browser must:

- Render the real on-disk directory tree for a repository root.
- Hide `.svn` directories only.
- Overlay SVN working-copy status on top of disk nodes.
- Keep `Normal` files viewable but not selectable for batch actions.
- Keep batch actions file-scoped: `Unversioned` files can be added, `Modified/Added/Deleted/Replaced` files can be committed.
- Avoid injecting virtual SVN-only nodes into the main tree.

The goal is to separate "what exists on disk" from "what SVN thinks about it" so the UI can scale from a change list into a usable working-copy explorer.

## Architecture

The feature is split into four bounded layers.

### 1. WorkingCopyDiskScanner

Responsible for reading the repository working directory from disk.

- Input: repository root path
- Output: disk nodes keyed by relative path
- Rules:
  - hide `.svn`
  - preserve real directory/file hierarchy
  - sort directories first, then files, then localized name order
  - support lazy loading by directory path

This layer knows nothing about SVN status semantics.

### 2. WorkingCopyStatusIndex

Responsible for querying SVN once and building a path-indexed status map.

- Source: `svn status --xml --depth infinity --no-ignore`
- Output:
  - `path -> FileStatus`
  - issue list for entries that do not map cleanly into the disk tree

Entries not present in the map are treated as `.normal`.

### 3. WorkingCopySnapshotAssembler

Responsible for combining disk nodes and SVN status index into UI nodes.

- Applies node status overlays
- Computes directory display status from descendants with this priority:
  1. `conflict`
  2. `modified / added / deleted / replaced`
  3. `unversioned`
  4. `ignored`
  5. `normal`
- Produces an auxiliary issue list for SVN-only states such as `missing`

This layer owns the translation from service data into view-facing state.

### 4. RepositoryViewModel / View

Responsible for interaction state and rendering.

- Tree source becomes the working-copy snapshot instead of raw `svn status`
- Directory expansion state is view-managed
- Selection remains path-based
- Right panel preserves current action model

## Data Model

The UI model is extended with explicit distinction between source state and display state.

### WorkingCopyNode

- `path`
- `name`
- `isDirectory`
- `status`
- `children`

`status` remains the display status used by the current UI. For files it is either the explicit SVN status or `.normal`. For directories it is an aggregated display status.

### WorkingCopyIssue

- `path`
- `status`
- `existsOnDisk`

This captures SVN-reported anomalies that cannot be represented by the disk-real tree, especially `missing`.

## Interaction Model

### Files Pane

- Displays all disk-real files and directories under repository root
- Hides `.svn`
- `Normal` nodes are visible and clickable
- Only actionable files render a checkbox
- Directories do not participate in batch selection

### Right Panel

Three modes remain:

1. No selection, clicked node exists:
   - show single node details
2. Selection exists:
   - show batch action panel
   - show addable count, committable count, blocked count
3. Nothing selected:
   - show empty state

### SVN Issues

SVN-only anomalies are not injected into the main tree.

Instead, the detail side exposes an `SVN Issues` section listing items such as:

- `missing`
- `conflict` items that need special handling
- other status entries not mapped to a disk-real node

This keeps the main tree faithful to the real filesystem while still surfacing repository health problems.

## Refresh Semantics

Refresh performs these steps:

1. reload SVN status index
2. clear disk tree cache
3. rebuild visible tree from disk
4. recompute directory aggregate status
5. prune invalid selection paths
6. clear stale detail selection if the disk node disappeared

Expansion state should be preserved where possible because the tree is now a browser, not just a transient change list.

## Error Handling

- Disk scan failures are reported through the existing repository error path.
- Missing or malformed SVN XML continues to surface as `SVNError`.
- If disk scan succeeds but status refresh fails, the repository view should still fail closed rather than render a partially mixed state. This keeps the tree/status overlay contract deterministic.

## Testing Focus

The implementation should be verified against:

- clean working copy with only normal files
- mixed tree with normal, modified, added, and unversioned files
- nested directories where only a deep child is modified
- ignored files when `--no-ignore` is enabled
- missing files reported by SVN but absent on disk
- selection pruning after refresh

## Non-Goals

This iteration does not add:

- recursive directory-level add/commit
- filesystem watching
- delete/revert flows
- virtual nodes inside the main tree for SVN-only entries

## Implementation Order

1. add disk-scan and snapshot assembly services
2. extend `SVNService.status` to return a full snapshot instead of only changed nodes
3. refactor `RepositoryViewModel` to load snapshot state
4. refactor `RepositoryDetailView` tree rendering and issue presentation
5. build and validate current add/commit behavior against the new tree source
