# Applications: handoff and window management

Applications uses the shared chooser keyboard model. Focus/launch hands control
to an application; Close manages its windows without leaving the chooser.

- **Focus:** dismiss on successful daemon completion. A rejected request leaves
  the panel usable with the error beside the selected application's commands.
- **Launch / New tile:** admission alone does not dismiss. App-daemon publishes a
  `running` operation with a checked launch receipt (`launch_backend` and
  `launch_scope`) after process/D-Bus handoff, before potentially slow window
  placement. Shelllist can dismiss then while retaining operation ownership.
  Older daemons without this progress receipt fall back to terminal completion.
- **Close:** send normal compositor close requests, never force termination.
  Keep the panel and selection. Say “Close requested,” not “Closed,” until a
  current catalog snapshot actually removes the requested window IDs. A remaining
  window offers Focus for inspecting a possible save prompt; Shelllist cannot
  tell whether a prompt exists. “Close all windows (N)” states the command's scope.
- **Last window:** show “No open windows” and a Launch primary, even if background
  processes still run. Window disappearance is not proof that the app terminated.

## Responsive, owned operations

`ApplicationOperations.qml` retains one in-flight action per application, up to
32 concurrent targets. Conflicting commands for that app remain disabled;
search/result browsing, detail-page navigation, refresh and other apps remain
usable. Screenshot/settings safety guards are unchanged. Per-window feedback and
the selected application's status explain pending/failure states. Status is
passive; Check status is a shared circular command (Alt+K), not a field Tab stop.
Removing a focused window-row command returns focus to shared detail browsing.

A view close is not an operation cancellation. The resident backend retains its
subscription while actions are pending. A late completion must not dismiss a
reopened panel, another selected result, or a view browsed since dispatch.
Background failures become ordinary Shelllist desktop notifications through
`notify-send` (packaged with the launcher); they respect notification policy and
never reopen or refocus the panel. The error is also retained with the app.

Only owned request/operation IDs, matching target/action and known lifecycle
states can change pending state. Early events before the admission response are
not trusted; owned status reads recover them. Duplicates and stale failures cannot
retire another operation. Event gaps trigger read-only status/catalog recovery.
No recovery path replays a launch or close.

Automatic operation-status checks are bounded to ten reads at two-second
intervals; Check status remains available afterward. Close reconciliation performs
up to three catalog observations, then relies on normal window events or explicit
refresh. An absent app in a filtered catalog does not prove its windows closed.
Feedback retains the latest 64 targets independently of pending ownership;
updating a target refreshes its position, and opaque keys cannot change the
cache's prototype. Success and failure share one owned status-read completion
path. An empty/malformed status response releases that read for bounded polling
or explicit Check status, without completing or replaying the mutation. Empty
request IDs and obsolete read failures cannot retire a newer read. A failed
status read does not complete the mutation. Transport loss explicitly reports an unknown outcome; check windows
before explicitly trying again. There is no misleading Cancel/Undo command.

## Validation

`tests/qml/tst_application_actions.qml` delivers real keys and pointer clicks to
Applications with a recording daemon transport. It covers handoff vs admission,
background tracking/failure, close acknowledgements versus observed disappearance,
last-window Launch, native focus recovery, concurrent targets, navigation while
pending, reopened/navigated views, failed reads and stale/foreign completions.
App-daemon tests cover retained owner-only launch receipts and terminal cancellation;
its isolated session suite covers launcher failure, timeout and ownership.
These are not live compositor/application-save-prompt or screen-reader acceptance.
