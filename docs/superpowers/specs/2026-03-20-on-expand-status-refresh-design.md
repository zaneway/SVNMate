## Overview

This spec adds status freshness on directory expansion.

The problem is not tree rendering itself; it is stale repository-wide SVN status state being reused when the operator expands a directory after the working copy has changed on disk.

The fix must:

- refresh working-copy status when a directory is expanded and the current status snapshot is stale
- debounce repeated expands over a short interval
- preserve expanded paths and selection context across the refresh
- fail closed on refresh errors instead of continuing to render stale statuses

## Design

### Freshness Model

`RepositoryViewModel` tracks the timestamp of the last successful working-copy status snapshot.

When a directory expand is requested:

- if the last successful snapshot is recent enough, reuse the current `statusIndex` only when the expanded directory has not changed on disk
- otherwise, fetch a fresh repository-wide `svn status --xml --depth infinity --no-ignore`

If the expanded directory modification time is newer than the last successful snapshot time, bypass the debounce window and refresh the repository-wide status immediately.

Recommended debounce window:

- `1.5s`

This keeps multiple quick expand actions from repeatedly re-running the same SVN command.

After the refresh decision is made, the expanded directory children should still be force-reloaded so stale per-directory nodes do not survive across disk changes.

### Why Repository-Wide Refresh

Status stays repository-wide, not directory-local.

This preserves consistency for:

- directory aggregate status
- added ancestor commit target completion
- conflict ancestor commit guards
- issue list generation
- tree-conflict detail loading entry points

### Context Preservation

Status refresh during expand must preserve:

- expanded directory paths
- selected file path
- selected action paths
- pending add-selection restoration

Tree-conflict detail cache may be cleared because status transitions can invalidate prior conflict metadata.

### Error Handling

If status refresh on expand fails:

- clear the stale snapshot state
- report the repository error
- do not continue showing stale statuses

This is preferable to rendering misleading `added`, `conflict`, or `normal` states after the underlying working copy has been replaced or invalidated.

## Non-Goals

This iteration does not add:

- background file-system watchers
- repository polling
- sidebar-wide repository health summaries
- automatic refresh of all repositories
