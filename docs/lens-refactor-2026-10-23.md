# QML quality refactor — 2026-10-23

Baseline: `4e699fc`, including the incoming `tests/qml/fixtures/bar-reads.json`
change, preserved byte-for-byte. Local qmlqualitylens 0.5.0 ran `measure quality.qml`
with the unchanged repository configuration. Evidence: `target/lens-refactor/`
(before/after reports, incoming patch/hash, differential script and validation logs).

## Changes and review decisions

- `bar/UpdateValidation.js` consolidates overview/history wire predicates and
  replaces the monolithic overview validator. Small named validators share bounds,
  nullability and collection checks; there is no generic schema interpreter.
  `UpdateController` retains request identity, retries and atomic publication.
- Notification Dismiss/Snooze/sender actions now fail closed without the shared
  `NotificationState`; duplicate Bar backend mutation adapters are removed.
  Unused direct bulk-clear adapters are removed, not native confirmed deletion.
  This improves ownership locality and reuse of existing guarded operations.
- Removed unused `RemovalAnimation` and nine helpers: `groupRecords`,
  `notificationMonitor`, `missingIntervals`, `protectionRange`, `renameSelected`,
  `moduleText`, `nowSummary`, `usageText`, `powerAreas`. Repository/sibling references
  and dynamic dispatch were reviewed; current chart, rename and native notification
  projection paths remain. TypeScript outputs were regenerated, not hand-patched.
- Removed unused IDs and unreachable branches of a test-only request helper;
  no test cases, discovery roots, guards or suppressions were removed.
- Retained shell IPC methods despite lacking QML callers, and the SystemTray enum
  export despite the lens reachability warning. Generated/tab-declaration clones
  are not justification for new abstraction layers.

## Measurements

Production scope below excludes `tests/`, `dev/` and `*.generated.*` records;
compiled TypeScript projections remain included once, as analyzed JavaScript.
Effort is the lens's advisory weighted metric, **not Halstead or developer hours**.

| Metric | Before | After |
| --- | ---: | ---: |
| Production source lines | 39,660 | 39,497 |
| Function cognitive sum / maximum | 6,507 / 70 | 6,485 / 41 |
| Function cyclomatic sum / maximum | 9,254 / 68 | 9,247 / 35 |
| Function effort sum / maximum | 40,838 / 282 | 40,692 / 179 |
| Entire configured source lines | 52,062 | 51,904 |
| Findings / advisory score | 925 / 82 | 918 / 83 |

Limits: splitting validators adds functions; peak reduction is much larger than
aggregate reduction. Halstead remains incomplete for nested callbacks; no aggregate
Halstead improvement is claimed. UpdateController's locality/leverage scores remain
10/30: ownership consolidation is not a measured improvement in those heuristics.
Clone reports remain capped at 100 groups (151 windows/55 groups omitted), so no
whole-project clone-count reduction is claimed; duplicated notification adapters
were removed directly. Parser diagnostics remain zero. Next substantive hotspots
are `IpEdit.replace`/`inspect` and `NotificationBackend.acknowledge`, not addressed here.

## Validation

Qt: **238 passed, zero failed, one existing RHI-only artwork skip**. Native Updates
checks now exercise malformed history through the transport/publication boundary;
the toast test covers missing-owner rejection through an actual dismissal click.
All **4,269 differential validator cases** matched the old implementation.
Strict qmllint, TypeScript generation check, generated protocol checks, daemon
boundary checks, source-tree relative imports and offscreen runtime smoke pass.
UI review reports zero new role/wrapper prompts. No full package build, hardware,
compositor/IME or human accessibility acceptance is claimed.
