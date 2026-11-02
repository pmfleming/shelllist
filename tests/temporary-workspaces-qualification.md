# Temporary workspaces: final qualification

## Follow-up: generated control contracts

The original qualification omitted `checks.x86_64-linux.generatedContracts`.
That check exposed seven registered workspace methods without control examples;
their unconstrained reply schemas also lacked required fields for mutation tests.
Rust now emits fixtures for all seven methods using the live DTOs and serializers,
with typed reply schemas and a registry-wide fixture coverage regression. The
frontend registry snapshot, generated bindings and control examples are refreshed.

Follow-up validation passed: the direct `node tests/check-generated-contracts.js`
check; `local-build build --attr checks.x86_64-linux.generatedContracts
/home/laufan/Projects/shelllist`; 304 Rust library tests with six existing skips;
strict all-target Clippy; and exact producer/checked-fixture/binding parity.
The JavaScript checker itself is unchanged.

2026-11-02. Domain policy, durable operations, allocation, placement, cleanup and
shortcut dispatch are Rust in app-daemon, bar-daemon and daemon-framework. Product
UI is Shelllist QML. The only native configuration additions are four declarative
Hyprland bindings. Existing Rust generators produce protocol JavaScript; no new
handwritten JavaScript, TypeScript, Python or shell implementation was added.

## Revision family

| Stage | Shelllist | app-daemon | bar-daemon | daemon-framework |
| --- | --- | --- | --- | --- |
| 1, contract/primitives | `56103d0` | — | — | `ee0af73` |
| 2, workspace owner | `4272d2c` | — | `00bc3b1` | `a39d5fe` |
| 3, launch routing | `813aa93` | `7cda7b2` | `5096158` | — |
| 4, QML controls | `6a1480c` | — | `858b918` | — |
| 5, integration/recovery | `b4422d1` | `6f935cd` | `933a326` | `c15595a` |
| 6, final qualification | this commit | `af3261a` | `103e734` | — |

NixOS bindings are committed separately as `73c14e5`. Stage 6 adds the private
journey, QML refusing-client fixture, monitor-migration regression and this
evidence. Use the final local-build source graph, not historical lock inputs.

## Real compositor and daemon evidence

The Rust `app-daemon/tests/workspace_journey.rs` fixture starts an isolated
Hyprland, session bus, app-daemon and bar-daemon with private runtime/config/data/
state directories. Its D-Bus activation fixture creates actual Wayland clients.
The test uses production version-2 daemon interfaces. It verifies:

- Explicit new-workspace launch produces a checked receipt and observed placement.
- Duplicate launch requests before and after app-daemon restart retain the same
  operation and never invoke activation twice.
- Bar restart preserves the allocation high watermark and fences old writers.
- Normal workspace close reaches the captured client.
- Killing app-daemon after activation but before the window maps leaves a durable
  unknown outcome. Restart, status lookup and duplicate admission do not relaunch.
  The late window cannot be placed into the released reservation.
- An actual QML client refuses close and opens a new save dialog. Both windows
  survive; the owner reports `still-open` without sweeping the new dialog.

Passing final fixture directory: `/tmp/wsj-1QB0ep`; log:
`/tmp/workspaces-journey-final.log`. Installed Hyprland is 0.56.2,
`efb50993780079460b0cbed1363e2166a2de1d9f`. Its render parent is the host Wayland
socket; all command IPC, bus traffic and clients target the private instance.

The framework's private compositor test separately passes atomic close-target
pinning, moved-target rejection, one-use identity, silent placement without
following the moved focused client, two-output foreign-workspace rejection and
background local focus without stealing keyboard focus. Its passing log is
`/tmp/workspaces-primitives.log`.

Reproduce the daemon journey with the pinned app development environment:

```text
cargo test --locked --test workspace_journey -- --ignored --nocapture
```

Set `WORKSPACE_TEST_PARENT_DISPLAY`, `WORKSPACE_TEST_HYPRLAND`,
`WORKSPACE_TEST_WESTON` (package root), `WORKSPACE_TEST_BAR` and
`WORKSPACE_TEST_DBUS` to the isolated fixture dependencies. The refusing-client
branch additionally uses `WORKSPACE_TEST_QML`, `WORKSPACE_TEST_QT_PLUGINS` and
`WORKSPACE_TEST_VETO_FIXTURE` pointing to
`tests/qml/fixtures/workspace-close-veto.qml`. Without those three variables that
branch is omitted; it was enabled for the recorded passing run.

## Interaction and static checks

- Final full native Qt suite: 712 passed, zero failures, one existing skip.
  Log: `/tmp/workspaces-helper-tests-final.log`. Targeted final lost-admission,
  old-catalog and explicit routing tests: five passed including setup/cleanup.
  Settings: four passed.
- Missing reply recovery reads the durable operation key and accepts an owned
  unknown result without dismissing the panel or replaying launch.
- Strict QML lint, generated TypeScript freshness and the Shelllist config
  package build pass through local-build.
- Panel review against `f3469e6` reports one shared ToggleRow composition prompt,
  accepted as documented in `temporary-workspaces-ui.md`; no new wrapper.
- Framework core/Hyprland tests: 25 passed. Strict Clippy passes for changed
  framework crates and all app/bar targets. Rust formatting passes.
- Final app library tests: 58 passed, three existing ignored opt-in tests.
  Workspace owner tests: ten passed, including lease/close fencing and migration.
- Legacy app session suite with the rollback flag: 18 passed, four pre-existing
  ignored fixtures. This verifies ordinary standalone launch behavior while the
  separate private journey verifies coordinated workspace behavior.
- Older app catalogs omit the two override actions while retaining ordinary
  Activate/Launch. Rust recognizes an explicit unsupported bar protocol, keeps
  ordinary default routing and rejects requests requiring the new owner.
  Timeout, malformed reply and unknown-effect responses never enable fallback.
- Workspace owner regressions include empty landing-pad monitor migration with
  unchanged identity and local MRU/live/unused-standard fallback ordering.
- Existing Hyprland shortcut registration checks pass, including duplicate-key
  detection. Rust CLI tests accept create/close/next/previous and reject force.

The final coordinated protocol/package build passed. Bar package checks ran
309 library tests plus 35 CLI/transport integration tests; app package checks
ran 58 library tests and 18 session tests. An intermediate package attempt failed
an existing session fixture's daemon-shutdown assertion; the final package rerun
passes that test without changing or suppressing it. Fixture parity also found
three nested bar snapshots missing the new lifecycle field; these were regenerated
from the final packaged Rust producer.

Final package outputs are `/nix/store/l8sw10mw402fii1q8l5rl0rl8a3hpq9i-app-daemon-0.1.0`
and `/nix/store/fqfw7n4l0p225rxk0qqyx3s2pc8297kq-bar-daemon-0.1.0`.
Final packaged QML qualification also passes: all seven producer-fixture diffs
match, followed by 712 Qt tests passed, zero failures and one existing skip.
The check derivation is
`/nix/store/q0v5ff686x81z8i4nllqxvs9d8ysivy4-shelllist-qml-tests.drv`.

Coordinated checks use the current local graph through `local-build`, for example:

```text
local-build build --attr checks.x86_64-linux.protocolBindings /home/laufan/Projects/shelllist -- --cores 4 --max-jobs 1
local-build build --attr checks.x86_64-linux.qmlTests /home/laufan/Projects/shelllist -- --cores 4 --max-jobs 1
local-build build --attr checks.x86_64-linux.qmlLint /home/laufan/Projects/shelllist
local-build build --attr checks.x86_64-linux.typescript /home/laufan/Projects/shelllist
local-build build --attr packages.x86_64-linux.shelllistConfig /home/laufan/Projects/shelllist
```

## Rollout limits

No production service was restarted, no compositor configuration was reloaded,
and no host configuration was activated. Real hardware unplug/replug, touchpad
gestures and interactive terminal/browser/editor/singleton acceptance remain
deployment checks. The automated close-veto fixture is not a claim that every
application's save-dialog implementation has been tested. Offscreen QML tests
use recording transports; the separate native journey tests actual daemons.

Unknown outcomes are deliberately retained without automatic effect replay.
The session journal has bounded admission rather than unbounded retention.
Rollback and matched deployment instructions are in
`contracts/temporary-workspaces-rollout.md`.
