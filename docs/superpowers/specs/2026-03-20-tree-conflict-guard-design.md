## Overview

This spec closes a correctness gap in the working-copy browser: SVN tree conflicts are currently not surfaced reliably, which allows the UI to offer commits that SVN will always reject.

The fix must:

- treat `tree-conflicted="true"` as a first-class conflict state
- surface conflict directories in the file browser
- block commits when any selected path is itself conflicted or sits under a conflicted ancestor directory
- expose `Resolve` for conflict directories, not only files

## Problem

`svn status --xml` exposes tree conflicts separately from the `item=` field. A directory can be reported as:

- `item="added"`
- `tree-conflicted="true"`

If the client only reads `item=`, the UI will misclassify the path as committable and defer failure until `svn commit`.

## Design

### XML Parsing

When parsing `wc-status`:

- if `tree-conflicted="true"`, the effective status becomes `.conflict`
- this override takes precedence over `item=`

This keeps the status model simple and lets the existing conflict coloring and conflict aggregation work without introducing a second UI-level conflict dimension.

### Commit Guard

Before running commit for selected paths:

1. compute the selected committable paths
2. refresh the latest working-copy status snapshot for preflight
3. compute all ancestor directories for those paths
4. if any selected path or ancestor directory has effective status `.conflict`, block commit in the UI
5. show the blocking paths so the operator can resolve them explicitly

This guard is intentionally client-side. SVN remains the final authority, but the user should not discover this class of rejection only after pressing commit, and the guard should not depend solely on a potentially stale UI cache.

### Resolve Exposure

The detail panel must expose `Resolve` whenever the selected node is `.conflict`, including directories. This is necessary because tree conflicts often land on directories rather than files.

## Non-Goals

This fix does not add:

- conflict explanation parsing
- merge assistance workflows
- automatic conflict resolution strategies
- recursive bulk resolve

## Validation

Validate with a local two-working-copy reproduction where:

1. working copy A deletes a directory and commits
2. working copy B modifies a file under that directory
3. working copy B updates and gets a tree conflict on the directory
4. the UI marks the directory conflicted
5. selecting descendant files no longer enables commit until conflict is resolved
