# Electrum login window handoff: workspace 7 retired

Investigated on 2026-11-04 against the running desktop. The original incident
evidence is followed by implementation and regression evidence below. The fix
has not been deployed to the running desktop.

## Finding

The launch-created workspace was retired during the gap between Electrum's
login/wizard window closing and its main wallet window mapping. Placement had
already completed for the first window and its workspace lease was released.
The workspace owner therefore treated the brief absence of windows as the end
of the workspace's lifetime. No explicit workspace-close request was recorded.

## Observed sequence

Times below are local CET on 2026-11-04, from the user journal.

- **01:24:06.173281:** app-daemon reported Electrum placed on workspace 7.
- **01:24:10.208789:** Hyprland logged the Electrum `Create/Restore wallet`
  window unmapping.
- **01:24:10.210222:** that window was destroyed.
- **01:24:10.286697–01:24:10.287615:** compositor IPC connections from
  bar-daemon PID 1848 surrounded the retirement transition.
- **01:24:10.287849:** focus changed to Chrome.
- **01:24:10.288034:** Hyprland logged `Destroying workspace ID 7`.
- **01:24:10.400964:** Electrum's main wallet window mapped, approximately
  192 ms after the first window unmapped and 113 ms after workspace destruction.

Both Electrum windows used compositor address `0x56d27a70b080`; the explicit
destroy/new-surface/map sequence shows that address equality is not proof of
window continuity. The launch receipt and current client both identify PID
179492.

The runtime app journal records operation
`operation-action-1793751845349-8` as completed, with placement on workspace 7
and a launch reservation requesting a newly allocated workspace. The matching
bar journal reservation has `placed: true`, `released: true`, and status
`released`. Workspace 7 is absent from the remaining entries. The journal's
`closes` object is empty.

The reported destination was workspace 3. The retained evidence establishes
the premature destruction of workspace 7, but does not establish that exact
destination: the immediate fallback focused Chrome on workspace 2, and the
later live snapshot showed Electrum on workspace 5. Subsequent keybindings are
logged at 01:24:25 and 01:24:28. Do not infer the initial destination from that
later snapshot. The active Hyprland configuration contains no Electrum-specific
workspace rule.

## Responsible code paths before the fix

In the sibling repositories inspected during this investigation:

- `app-daemon/src/service/action.rs:523–551` waits for one eligible new window,
  applies its placement, and immediately returns success.
- `app-daemon/src/service/workspaces.rs:89–99` releases the reservation when
  its guard drops after the launch operation.
- `bar-daemon/src/workspace/mod.rs:833–865` retains workspaces with windows,
  leases, pending closes, or applicable manual retention, but provides no
  handoff grace period for a previously occupied launch-created workspace.
- `bar-daemon/src/workspace/mod.rs:867–907` focuses a fallback when the empty
  workspace is active, then removes its logical entry.

These paths explain the observed sequence. The contract at investigation time
allows automatic retirement of launch-created workspaces once windows and
leases settle; it does not account for replacement windows during login.

## Fix requirements and verification

Coordinate launch ownership and workspace retirement across replacement-window
handoffs. Preserve the destination through a bounded empty interval and retain
verified process provenance for replacement placement. A delay alone does not
cover replacements appearing after the user switches workspaces. Do not match
by class alone or assume an address/PID pair identifies the same window forever.
Respect explicit close, manual movement, process exit, and lost focus intent.

Add an actual Qt/compositor regression fixture that maps a login window,
destroys it, waits approximately 200 ms, and maps a replacement from the same
process. Verify destination retention and placement, eventual cleanup on real
exit, and cancellation after explicit close or user movement. Also cover a
longer delay and address reuse where feasible.

The initial investigation used read-only journal, runtime receipt, compositor
snapshot, and source inspection. It did not restart Electrum, move its windows,
or change the desktop configuration.

## Implemented correction

The workspace owner in `bar-daemon` now retains an occupied temporary workspace
through a two-second empty interval and schedules its own cleanup wake. The
verified initial placement also records a bounded replacement observer, separate
from the released caller lease. The observer captures PID, Linux process start
time, and a weak Hyprland window reference; it transfers one unambiguous
same-process successor to the original destination without following focus.
The grace starts when the predecessor disappears, not when the app launches.

`daemon-framework` supplies guarded observation/replacement primitives. Manual
movement, explicit close, process exit/reuse, ambiguous replacements, lost
identity, compositor disconnect/config reload, superseding placement, and owner
restart cancel the observer. An uncertain dispatch is not replayed. Cross-process
successors are outside this fix. Public wire types and QML navigation are unchanged.
The maintained behavior is specified in `contracts/temporary-workspaces.md`.

## Regression evidence

`bar-daemon/tests/workspace_handoff.rs` launches the real daemon on a private
session bus and nested Hyprland, with isolated state/configuration and no system
bus access. `tests/fixtures/workspace-handoff.qml` creates, destroys, and replaces
real Qt windows in one process. These cases pass against Hyprland 0.56.2 and
Qt 6.11.2:

- Keep the login window open longer than two seconds, then replace it after
  200 ms: the launch destination survives.
- Switch away, then replace after 1.2 seconds: the successor returns to its
  launch destination without stealing focus.
- Move the original window manually: replacement does not revive old placement.
- Explicitly close the workspace during the gap: replacement does not revive it.
- Wait three seconds: expired placement is not revived.
- Exit the Qt process after each case: the temporary workspace retires.

The owner unit suite additionally covers reused compositor addresses, movement
away and back before reconciliation, PID/start-time mismatch, owner restart,
disconnect, lost pins, and cleanup without subsequent compositor events.

Run the opt-in compositor test from the bar-daemon Nix development shell with
absolute paths supplied in `WORKSPACE_TEST_HYPRLAND`,
`WORKSPACE_TEST_PARENT_DISPLAY`, `WORKSPACE_TEST_DBUS`, `WORKSPACE_TEST_QML`, and
`WORKSPACE_TEST_QT_PLUGINS`:

```sh
cargo test --test workspace_handoff -- --ignored --nocapture
```

The fixture prints its private `/tmp/handoff-*` evidence directory. This verifies
the Qt replacement behavior; it does not authenticate to or open a real wallet.

Validation on 2026-11-04:

- Bar daemon: 350 tests passed across all targets; nine opt-in tests were skipped
  by the normal run. The new Qt test was then run explicitly and passed all five
  scenarios. Its final evidence directory was `/tmp/handoff-ug6wM7`.
- Shared Hyprland crate: 11 tests passed.
- Bar daemon: all-target build check, Clippy with warnings denied, rustdoc with
  warnings denied, and formatting check passed.
- Shared Hyprland crate: all-target Clippy and framework formatting check passed.

These changes are source changes requiring a rebuild and deployment before the
running desktop gains the corrected behavior.
