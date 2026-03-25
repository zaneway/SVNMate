## Summary

Add double-click behavior for directory rows in the working copy browser.

## Goals

- Double-clicking a directory row toggles expand/collapse
- The directory remains selected after the double-click
- The detail panel continues to show that directory
- Existing single-click selection and checkbox behavior remain unchanged

## Non-Goals

- Changing file double-click behavior
- Refactoring the tree to `OutlineGroup` or AppKit
- Changing lazy loading or refresh-on-expand behavior

## Design

The implementation stays inside `FileTreeNodeView`:

- single click continues to select the clicked node
- double click on a directory row:
  - selects the directory
  - calls the existing `onSetExpanded(node, !isExpanded)`

This reuses the existing expand pipeline, so refresh-on-expand, lazy child loading, and tree state restoration all remain intact.

## Validation

1. single click on files and directories still selects
2. double click on a collapsed directory expands it and keeps it selected
3. double click on an expanded directory collapses it and keeps it selected
4. checkbox selection and chevron button continue to work
