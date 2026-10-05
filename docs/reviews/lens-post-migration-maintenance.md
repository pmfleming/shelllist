# Post-migration QML Quality Lens maintenance

## Method and scope

Baseline: Shelllist `8ca74ce`, including the pre-existing `flake.nix` worktree
change, which was preserved byte-for-byte. The locally available
`../qmlqualitylens` checkout was already dirty; its sources were not edited.
Built output was frozen for both measurements (checkout base `abc9647`,
build digest `2c8586709b1ee8ee7ca97c4cbf889cafc4a06a5a3cecafea3ee627f4a510a6c9`).
Repository Lens configuration remained unchanged:
`589b22a3f8c12f3fb32669e22285e17164705e3a7ca1de52af475b2bccb1324f`.
No roots, thresholds, suppressions or test scopes were relaxed.

Local evidence is in `target/lens-review-portal/`: `before`/`final` structural
reports and summaries, complete clone scans, `before-tools`/`after-tools` native
reports, frozen analyzer, baseline archive and `differential.cjs`.
`snapshot.mjs LABEL` runs structural analysis without external/imported reports;
separate frozen CLI `measure all` runs execute the configured native checks.
Native configurations only override absolute project/output destinations.

## Changes and preserved boundaries

- **Read-only bar projections:** `qml/Shelllist/Io/BarProjectionBackend.qml` shares snapshot,
  subscription, gap recovery and read-error plumbing between compositor-motion
  and work-area consumers. They retain their own validation and failure policy:
  motion preserves reduced motion and revision on a failed read, resetting the
  revision only on transport loss; geometry clears unavailable insets. Queued
  reads still check `active`. No system polling or policy moved into QML.
- **OSD presentation:** `bar/BarOsdPresentation.js` constructs one complete payload
  schema. Renderers supply differences; labels, icons, timeouts, percentages,
  event ordering and mutable-object isolation remain unchanged. This removes
  repetition, not domain validation. Its function cyclomatic sum increases by
  one for the constructor; effort decreases from 400 to 388.
- **Display reconciliation:** one named layout-change predicate replaces repeated
  fingerprint/preference checks. Trial topology invalidation, dirty drafts,
  pending Preview protection and acknowledgement guards remain intact. No
  keyboard, geometry or field-save model changed.
- **Concrete screen types:** six screen-object `var` properties become
  `ShellScreen`, including native `Variants` delegates. Dynamic protocol payloads
  remain dynamic; no unchecked cast or lint suppression replaces them.
- **Verified unused code:** removed `NotificationStackHeader` and its registration,
  `NotificationPresentation.previewCapacity`/`relativeTime`, battery presentation
  `clamp`, `ActivityController.requestTimeWeather`, and the unused portal root ID.
  Deletions were checked against repository references, not accepted solely from
  Lens reachability heuristics.

## Measurements

Production excludes `tests/` and `dev/` consistently in both snapshots. Means are
unweighted component scores; complexity/effort are sums of Lens records. These
are structural heuristics, not runtime speed measurements.

| Metric | Production before → after | All configured sources before → after |
| --- | ---: | ---: |
| Source LOC | 37,443 → 37,340 | 45,859 → 45,812 |
| Physical LOC | 41,875 → 41,769 | 50,577 → 50,529 |
| Cyclomatic complexity | 7,281 → 7,264 | 7,916 → 7,906 |
| Cognitive complexity | 4,894 → 4,883 | 5,171 → 5,165 |
| Function effort | 36,685 → 36,600 | 42,665 → 42,634 |
| Component effort | 41,205 → 41,108 | 50,713 → 50,679 |
| Mean locality | 75.9826 → 76.1045 | 76.8314 → 76.9349 |
| Mean leverage | 36.2369 → 36.3415 | 32.3373 → 32.4260 |
| Clone groups | 128 → 124 | 169 → 165 |
| Clone-covered lines | 1,867 → 1,795 | 2,521 → 2,449 |
| `property var` | 446 → 440 | 475 → 469 |

Tracked physical source LOC (`qml/js/ts/mjs/py/sh/nix/rs`, including tests and the
new backend) falls **56,223 → 56,175**, a net reduction of **48 lines**.
Documentation and generated local audit artifacts are not counted as code.
Component counts remain 287 production / 338 overall. Unknown-signal escapes
remain zero; scoped qmllint-disable markers remain 15. Overall heuristic score
remains **83**. These are modest improvements, not a wholesale complexity fix.

Clone totals use the same window threshold and expanded scan limits (200,000
keys, 1,000 windows/key, 10,000 groups), with zero omitted windows/groups in both
runs. The default native audit's clone scan is partial and is not used for totals.

## Validation and remaining review work

- Actual Qt suite: **302 passed**, zero failures/skips. Regressions cover projection
  isolation, different read-failure policies, deferred inactive refresh, pending
  display-preview telemetry and OSD schema/default isolation.
- Strict qmllint and both native runtime smokes pass, including typed Quickshell
  screen delegates. Notification presentation, battery controls, display model
  and daemon-boundary checks pass.
- The isolated Nix `qmlTests` derivation and an independently reconstructed
  packaged import layout both pass all 302 Qt checks. An initial test-only import
  was corrected to the logical `qml/Shelllist/Bar` path rather than requiring a
  nonexistent packaged root-level `bar` link.
- Frozen-baseline differential checks pass for **1,205 OSD cases** and **2,048
  display reconciliation combinations**. These supplement, not replace, Qt tests.
- Lens native parser oracle passes all 338 QML files; qmllint covers all 392
  configured QML/JS files. Test execution and runtime-warning evidence pass.

The **full coordinated sibling gate is not complete**. A cold run was interrupted;
a fresh snapshot was blocked by concurrent, untracked `shelllist-local-build`
crate files in `../daemon-framework`. That worktree was left untouched. The
isolated Qt result is not evidence of a successful current-family release gate.

Lens still reports **incomplete**, not a clean quality verdict: dynamic binding
side-effect proof is incomplete, runtime coverage omits part of the QML scope,
and qmlformat still fails on the existing `SystemTrayItem.qml` test double.
Formatter drift remains 104 files; review findings fall 750 → 748, with zero
verified/semantic failures. No matched runtime benchmark baseline was supplied,
so no performance improvement is claimed. Live compositor/hardware acceptance
is separate; no service was activated or restarted.

The largest hand-written cognitive hotspot remains `NotificationBackend.finish`
(cyclomatic 25, cognitive 32). A later acknowledgement/history transaction split
needs dedicated stale-generation, cursor and transport regressions; removing its
safety checks would be a false improvement. Generated Material Colors/protocol
code and similarly shaped but unrelated option lists were deliberately left alone.
