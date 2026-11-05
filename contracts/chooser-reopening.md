# Completion-aware chooser reopening

Applications and Clipboard opt into a clean next invocation after a completed
handoff. Other panels retain their existing reopening behavior. Ordinary
dismissal, switching panels, failure, cancellation and unknown outcomes do not
themselves request a reset.

## Completion boundaries

- Applications uses the existing owned launch/focus/desktop-action handoff.
  Admission alone is insufficient. A checked process/D-Bus launch may hand off
  before placement finishes; its pending operation and later warnings remain
  owned and recoverable. Closing application windows is not a handoff.
- Clipboard copy requires an owned `completed` operation. Request and operation
  identities prevent an older copy from completing a newer copy's view.
- Clipboard paste, including image-as-file and native save-and-paste, requires
  the owned session wait to report the matching session as `finished`. Preparing
  the paste or hiding the picker is insufficient. The connection remains alive
  through dispatch. Annotation's temporary hide does not request a reset.

Completion captures the UI generation and interaction epoch. It may mark the
current invocation or that invocation while hidden, never a reopened one. New
search, keyboard/pointer result navigation, detail navigation, category changes
or another submitted action supersede completion. Escape preserves an already
completed invocation's reset while retaining the existing dismissal and editor
discard behavior. No reset moves the current view under the user.

## Clean next opening

On the next activation, clear the query, select result zero, scroll the list to
the top, collapse details and focus search. Applications also clears its
temporary category filter; Clipboard requests a fresh first page. Async ranking
and catalog replies keep the first result selected until the user navigates;
Clipboard's current-entry restoration cannot override that initial selection.
Subsequent navigation restores ordinary stable-result selection.

Only invocation presentation is reset. Keep saved settings, per-result detail
tabs/locations, operation ownership, diagnostics, retries and domain safety
guards. Existing field save/discard, paste ownership and background operation
lifecycles remain authoritative. No reset replays a domain action.

## Native evidence owners

- `tests/qml/tst_chooser_memory.qml`: native search/result browsing, completion,
  next-opening focus/scroll, late Rust ranking and continuation cancellation.
- `tests/qml/tst_application_actions.qml`: launch/focus/desktop-action handoff,
  admission versus completion, category reset, retained pending operations,
  rejection, window closing and old-operation/new-invocation isolation.
- `tests/qml/tst_clipboard_recovery.qml`: native copy/paste commands and Escape,
  confirmed/failed/unknown outcomes, continuation, hidden paste ownership,
  stale sessions, reopening before completion and fresh-page selection.

These tests use actual Qt controls and recording transports, not live desktop
launches or clipboard mutations.
