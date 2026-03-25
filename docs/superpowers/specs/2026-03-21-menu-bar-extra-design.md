# Menu Bar Extra Design

## Goal

Add a menu bar icon to the existing macOS window application without changing the current Dock and main-window behavior.

The menu bar extra should provide:

- a persistent status bar icon
- a lightweight selected-repository summary
- fast entry points for common actions

## Scope

This iteration keeps the app as a normal windowed macOS application.

It adds:

- `MenuBarExtra`
- selected repository summary
- repository count summary
- quick actions for show/open/checkout/settings/quit

It does not add:

- LSUIElement agent mode
- hiding the Dock icon
- a full repository browser inside the menu bar
- background polling of all repositories

## Summary Model

The menu bar only summarizes the currently selected repository.

Summary fields:

- selected repository name
- selected repository path
- tracked repository count
- selected repository SVN issue count
- refresh/loading state

Issue count is computed from a fresh `workingCopySnapshot` of the selected repository when the menu content appears or when the selected repository changes.

## Menu Structure

Top summary section:

- current repository label
- repository count
- issue count or loading message

Action section:

- `Show SVNMate`
- `New Checkout...`
- `Open Repository...`
- `Refresh Summary`
- `Settings...`
- `Quit`

## Icon State

The menu bar icon is stateful:

- busy summary refresh or global loading -> refresh icon
- selected repository has issues -> warning icon
- normal selected repository -> package icon
- no repository selected -> outline package icon

## Window Behavior

Clicking menu actions should not convert the app into a menu-bar-only app.

`Show SVNMate`, `New Checkout...`, `Open Repository...`, and `Settings...` should activate the application and bring a window forward if needed.

## Refresh Strategy

The issue summary is refreshed for the selected repository only.

Triggers:

- menu content appears
- selected repository changes
- explicit `Refresh Summary`

No global polling is introduced.

## Failure Handling

If summary refresh fails:

- keep the menu bar extra available
- show an inline summary error string
- keep the rest of the actions usable
