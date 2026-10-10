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
- **Workspace placement:** app-daemon owns category routing, process attribution
  (including UWSM scope migration, D-Bus and established singleton processes), and
  compositor verification. Optional `placement` reports `workspace_id`, `status`
  (`pending`, `placed`, `unavailable`, `failed`) and a failure `reason`. A completed
  launch with unavailable/failed placement is a partial success, not permission
  to launch again. Shelllist retains the daemon message and shows a background
  notification if handoff already dismissed the chooser; otherwise the warning
  remains inline without dismissing it. Owned status recovery uses the same path,
  duplicates do not notify twice, and old daemons without `placement` retain their
  existing behavior. New windows use the category workspace; existing windows
  remain where they are. No new field stops, shortcuts or retry commands.
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
usable. Screenshot/settings safety guards are unchanged. The selected application's
fixed list status bar communicates launch/focus/close initiation, progress and
confirmed outcomes, including failures and unconfirmed closes. It remains available
with details collapsed or on any detail tab; full diagnostics remain accessible.
There is no Check status row, button or Alt+K command. Recovery runs automatically;
status is passive and adds no field stops. Successful focus/launch still dismisses
at the existing handoff boundary, without delaying handoff to display completion.
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
retire another operation. The owner separates active publication/handoff from
terminal retirement after this shared gate. One terminal warning decision keeps
failed actions, placement partial success and unconfirmed Close distinct from
successful handoff; irrelevant launch receipts or placement metadata cannot turn
Close into a handoff. Event gaps trigger read-only status/catalog recovery.
No recovery path replays a launch or close.

Automatic operation-status checks are bounded to ten reads at two-second
intervals; an unconfirmed outcome remains in the status bar afterward. Close reconciliation performs
up to three catalog observations, then relies on normal window events or explicit
refresh. An absent app in a filtered catalog does not prove its windows closed.
Feedback retains the latest 64 targets independently of pending ownership;
updating a target refreshes its position, and opaque keys cannot change the
cache's prototype. Success and failure share one owned status-read completion
path. An empty/malformed status response releases that read for bounded automatic
polling, without completing or replaying the mutation. Empty
request IDs and obsolete read failures cannot retire a newer read. A failed
status read does not complete the mutation. Transport loss explicitly reports an unknown outcome; check windows
before explicitly trying again. There is no misleading Cancel/Undo command.

## Validation

`tests/qml/tst_application_actions.qml` delivers real keys and pointer clicks to
Applications with a recording daemon transport. It covers handoff vs admission,
background tracking/failure, close acknowledgements versus observed disappearance,
last-window Launch, native focus recovery, concurrent targets, navigation while
pending, reopened/navigated views, failed reads and stale/foreign completions.
It also covers placement partial-success warnings before/after handoff and via
owned status reads, visible status-bar progress/completion (including collapsed
and tabbed details), removal of Check status and Alt+K, automatic status recovery,
legacy absent placement, closed/still-open/unknown/missing
Close observations, cancelled/failed Close, foreign/duplicate outcomes, retained
window identities and feedback, continued native navigation and the absence of
automatic relaunch or duplicate refresh/notification. App-daemon tests cover retained
owner-only launch receipts and terminal cancellation; its isolated session suite
covers all five category mappings across launch paths, scope migration, D-Bus and
singleton attribution, existing-window exclusion, ambiguous/unrelated windows,
rejected moves and compositor verification timeouts.
These are not live compositor/application-save-prompt or screen-reader acceptance.
