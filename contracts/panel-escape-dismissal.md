# Panel Escape dismissal

The Escape that closes a panel belongs to Shelllist through its physical key
release. `PopupWindowHost` routes close requests through the shared
`EscapeDismissalScope` in both popover and floating `VisualSurface` instances.
If Escape is down, the host snapshots/suspends navigation, keeps the native
window mapped and focused, consumes further presses, and closes on key-up.
There is no timeout that could hand a still-held Escape to the application below.

The scope observes shortcut-override events without taking Escape away from
editors, dialogs or domain back-navigation. Discarding an edit, dismissing a
dialog and collapsing details still happen on press. Only a final window close
waits for release; non-keyboard close requests without Escape held stay immediate.
Domain validation, acknowledgements, safety guards and field transactions keep
their existing ownership. This introduces no new navigation or editable stop.

Navigation is captured before the scope takes focus to consume repeated presses.
External hiding clears held-key/pending state so a later opening cannot inherit
an old release. If native focus is lost while a close is pending, finish that
already-requested close because this window may no longer receive key-up.

## Evidence

- `tests/qml/tst_escape_dismissal.qml`: native Qt press/release through the real
  `VisualSurface` and standalone `PanelSurface`; field discard before close,
  pending input consumption, immediate non-keyboard close, external hide/reopen,
  and focus transfer to an unrelated native Qt window during a pending close.
- `tests/qml/tst_system_choosers.qml`: actual Media search and result-list Escape,
  including details collapse before final dismissal and no close while held.
- Existing chooser keyboard, field interaction and chooser memory suites retain
  modal cancellation, edit transactions and navigation restoration coverage.

The five targeted Qt suites pass (37 passes including lifecycle hooks, zero
failures). Changed-file and repository-wide QML lint and the native offscreen
runtime smoke pass.

Offscreen Qt verifies window-close ordering and event consumption, not physical
key routing through a live compositor. Desktop acceptance: open Media over an
application where Escape exits fullscreen or cancels a dialog, hold the final
Escape, then release; only the Shelllist panel should close. Repeat from search,
results and a standalone panel, including holding past the keyboard repeat delay.
