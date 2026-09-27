# Post-keyboard shared-UI maintenance — 2026-09-27

Baseline: clean `668b0f1b1ad4a00667c6d0477941452f6b29fd03`.
Analyzer: local QML Quality Lens `80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`,
v0.5.0, Qt 6.11.1. Configuration, source roots, thresholds, entrypoints and
suppressions are unchanged. No tests were removed or skipped.

## Review and refactoring

- **Shared search:** `Core.SearchService` retains its lazy worker but accesses
  an explicitly exported `Io.SearchProcess` type. Three dynamic-property lint
  suppressions and one `ignoreUnknownSignals` escape hatch disappear. The
  remaining Quickshell process-exit suppression is required: Qt lint still
  cannot resolve its `QProcess::ExitStatus`, even with no handler parameters.
- **Typed collections:** provider prefixes and detail browse targets use typed
  lists. A native test caught Qt's list-versus-Array distinction; provider
  descriptors now convert prefixes with `Array.from` before normalization.
- **Common motion:** `InteractiveBehavior` now interpolates both numeric and
  color properties, with explicit duration/easing overrides. Shared chooser
  controls (Wi-Fi, Bluetooth, clipboard and applications) and bar controls reuse
  it instead of copying animation blocks. Existing durations, easing, OSD
  interruption, drag bypass and flat-button focus bypass are preserved. This
  does not change spring tuning or reduced-motion policy.
- **Bar locality:** `MediaControls` owns the four existing buttons and one inline
  style. `MediaChip` retains artwork, track information, progress and background
  clicks. Capabilities, action IDs, asymmetric seek intervals and pointer hit
  regions are unchanged; this is not the future bar redesign.
- **Keyboard complexity:** region traversal uses an ordered set of destinations;
  browse-target discovery reuses its existing editable-control predicate. A
  trial switch-based key dispatcher increased effort and was discarded.
- **Dead/redundant code:** remove an unused Wi-Fi sharing forwarder, clipboard
  detail-close/toggle overrides identical to the shared chooser, an unused
  navigation ID, and normalized action defaults repeated in Applications/Wi-Fi.
  Domain recovery, secrets, leases and operation state machines remain separate.

## Measurements

Production includes configured shared/domain QML and JS, the gallery and
generated outputs; tests are reported separately. Extraction costs are included.
These are modest improvements, not a wholesale architectural transformation.

| Metric | Production before → after | All analyzed code before → after |
| --- | ---: | ---: |
| Cyclomatic | 7,547 → 7,536 | 7,935 → 7,926 |
| Cognitive | 9,124 → 9,109 | 9,331 → 9,317 |
| Function effort | 44,758 → 44,677 | 48,862 → 48,802 |
| Component effort | 41,752 → 41,589 | 48,055 → 47,946 |
| Mean locality | 75.2096 → 75.2967 | 76.7778 → 76.7943 |
| Mean leverage | 53.1397 → 53.1758 | 50.5556 → 50.5601 |
| Source LOC | 36,353 → 36,246 | 41,989 → 41,923 |
| Physical LOC | 40,835 → 40,721 | 46,736 → 46,665 |
| Clone groups | 156 → 149 | 193 → 185 |
| Clone-covered lines | 2,221 → 2,112 | 2,788 → 2,665 |
| `property var` | 423 → 421 | 451 → 449 |
| Unknown-signal suppressions | 3 → 2 | 3 → 2 |
| Lint-disable directives | 19 → 16 | 19 → 16 |

Broader tracked `qml/js/ts/mjs/py/sh/nix/rs` code, including canonical sources,
generated outputs and tests: **52,241 → 52,168 physical lines (−73)**.
Documentation is outside this code count. Both expanded clone scans are complete
at 200,000 keys / 1,000 windows per key / 10,000 groups, with zero omitted
windows/groups. Default Lens clone reports remain capped and are not used here.

`cycleRegion` cyclomatic/cognitive/effort is **10/16/65 → 7/6/30**;
`collectTargets` is **15/15/68 → 11/11/54**. `MediaChip` effort is **275 → 175**,
plus **78** for its extracted controls; locality is **0 → 14** (controls: **84**).
`InteractiveBehavior` observed uses rise **4 → 27** including tests, but its own
effort rises **17 → 22** and locality falls **100 → 96**. Those extraction costs
and local regressions are not hidden by the improving aggregate means.

## Validation and residuals

Strict lint, **128 behavioral cases / 200 Qt passes including hooks**, runtime
smoke, fresh Lens execution, and the full sibling-aware Nix gate pass. The new interpolation test compares actual
Qt numeric/color animations with native references, reversal and disabled-motion
end states. Existing keyboard, pairing/secret recovery, clipboard drafts,
application settings, bar pointer/OSD, and display safety tests remain.
**20,000 seeded application/Wi-Fi action projections** and **all 32 region-focus
combinations** match the baseline; inputs remain unchanged.

Lens remains **warn**, score **83**, with no verified or semantic failures.
Review findings fall **936 → 932**. There are no unused component/ID findings;
six unused palette-role candidates remain intentional Material API, not proven
dead code. Lens still lacks the built-in `SpringAnimation` type (native lint is
clean); formatting drift remains **33 → 33**. Profiler observations cover
**248/315 → 249/316** QML files, not statement/branch coverage. No live deployment, service restart, compositor or hardware acceptance
was performed.

Evidence: `target/lens-keyboard-maintenance/{before-tools,after-tools}/`, baseline
archive/revision/config hash and `differential.cjs`; complete static snapshots
under `../qmlqualitylens/target/shelllist-maintenance/keyboard-{before,after}*`.
Logs: `/tmp/shelllist-refactor-{before-tools,after-tools,after-lens,full-check}.log`.
Reproduce with the commands in [the quality gate guide](../qml-quality-review.md)
and `node target/lens-keyboard-maintenance/differential.cjs` from the repository
root. Use the same local Lens and sibling-aware development graph on both sides.
