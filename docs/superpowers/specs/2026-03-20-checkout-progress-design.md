# Checkout Progress Streaming Design

## Goal

Improve checkout UX in two ways:

1. Stream SVN checkout output into the macOS sheet while the command is running.
2. Extend checkout timeout from the shared network timeout to 30 minutes.

The UI must show:

- the latest "currently checking out" message
- all emitted checkout file lines so far

## Problem

The current command runner waits for process exit and only reads stdout/stderr once at the end. This prevents the UI from rendering in-flight checkout progress. Checkout also uses the generic network timeout of 300 seconds, which is too short for large repositories or slow links.

## Design

### Runner

Keep the existing non-streaming `run(...)` API for the rest of the codebase. Add a second API that streams stdout/stderr lines while still returning a final `SVNCommandResult`.

The streaming API should:

- accept optional stdout/stderr line callbacks
- emit complete lines instead of raw bytes
- preserve timeout and cancellation behavior
- still capture full stdout/stderr for post-run success and failure handling

### Service

Add a dedicated checkout timeout constant:

- `checkoutOperation = 1800`

Expose a checkout API that accepts a progress callback and forwards streamed stdout/stderr lines to the caller without adding UI-specific interpretation inside the service layer.

### UI

Extend `CheckoutSheet` state with:

- `checkoutLogLines`
- `currentCheckoutMessage`
- `checkoutTask`

During checkout:

- disable repository URL and target directory inputs
- render a scrollable log area with all received output lines
- render a status line that updates as new file lines arrive

The sheet should derive the current status text from the latest emitted line:

- file action lines like `A path`, `U path`, `D path`, `C path` -> `Checking out: <path>`
- revision completion line -> `Checkout completed`
- other lines -> pass through as-is

## Failure Handling

- If checkout fails, keep the already streamed log visible in the sheet.
- If checkout times out, the error should clearly indicate the 30-minute timeout.
- The user should not be able to dismiss the sheet via the Cancel button while checkout is in progress, preventing a detached background process from continuing without UI ownership.

## Non-Goals

- Global background operation center
- Streaming progress for update/log/commit in this iteration
- Rich semantic parsing of every possible SVN output variant
