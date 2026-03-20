## Overview

This spec adds structured tree-conflict detail display to the repository detail panel.

The client already detects and blocks tree-conflicted paths from commit. This iteration makes those conflicts explainable by surfacing:

- the conflict summary
- source-left metadata
- source-right metadata

The detail is loaded lazily from `svn info --xml <path>` for the currently relevant conflict path.

## Design

### Data Source

Tree-conflict detail is parsed from `svn info --xml`, not from plain-text `svn status`.

Required fields:

- `kind`
- `reason`
- `action`
- `operation`
- `victim`
- `source-left`
- `source-right`

### Loading Strategy

Use lazy loading and per-path caching.

- when a conflict file or directory is selected, request detail once
- when batch selection is blocked by a conflicted ancestor, request detail for the first blocking path
- clear the cache on repository refresh because conflict state may change after update or resolve

### UI

Add a `Tree Conflict` section to the right panel.

The section shows:

1. summary line
2. victim metadata
3. source-left block
4. source-right block

The summary should mirror SVN wording closely, for example:

`local dir edit, incoming replace with dir upon update`

### Non-Goals

This iteration does not add:

- automatic conflict interpretation beyond SVN-provided fields
- merge assistance
- multi-conflict dashboard views
