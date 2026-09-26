# Post-Material maintenance review — 2026-09-27

## Scope and method

Compared Shelllist `ee481c9bad70b397c702e77b04676f6d3e3bf383` with
`d49d0348537f15f72478e20a59a67cc5923c0453`, using local qmlqualitylens 0.5.0,
commit `80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`.

The unchanged `qmlqualitylens.config.json` has SHA-256
`db705901e7f43638a7584e23e501261c640e677befaadcab0834e723f731c37f`.
No roots, exclusions, thresholds, suppressions or dynamic edges were changed.
Generated sources, including the Material color library, remain in both samples.
These totals must not be compared directly with the pre-Material baseline.

Structural snapshots disable external execution; final execution evidence was
collected separately with the configured `measure all` command. Complete clone
scans use 200,000 keys, 1,000 windows per key and 10,000 groups, with **zero omitted
windows/groups**. Default capped Lens clone output is partial, not the basis of
the totals below. Metrics describe review heuristics, not correctness or elapsed
development effort.

## Changes

1. **`9d32efc` — unused controller entry points.** Removed 14 unreferenced
   functions across activity, battery, Bluetooth, notifications and Wi-Fi,
   including redundant inventory/statistics/scanner forwarding methods. Checked
   call sites, workspace consumers and resident dispatch boundaries; these are
   in-repository implementation methods, not an external toolkit contract.
   Retained the real scanner, subscription cleanup, notification routing and
   daemon operations. Removed the unused adapter-sync `force` argument and its
   ineffective caller expressions. No tests were deleted.
2. **`125f8f5` — display editing and projection.** Normalize the requested value
   once, outside the per-output map; preserve unrelated output objects, invalid
   editor input, mirror restrictions and preview-only mutation. Give single-output
   result projection a named unit, consistent with other providers, rather than
   nesting it inside collection traversal. Type `DisplayBackend.controller` as
   `DisplayController`, removing a genuine QObject `var` escape hatch. Added a
   regression test for numeric fields, invalid input, unknown targets/keys and
   the absence of daemon writes while editing.
3. **`ff95d11` + `d49d034` — shared bar indicators.** One typed helper owns bounded
   percentages, audio thresholds and power-profile glyphs for status, OSD and
   media presentation. Consumers no longer duplicate those implementations or
   borrow a numeric helper from the OSD module. Canonical TypeScript, the
   generation manifest and checked-in JavaScript are synchronized and checked.
   Node tests now evaluate presentation modules in separate VM contexts: the old
   shared global context could mask missing imports by supplying another module's
   private functions. Expanded boundary tests and **45,000 seeded before/after
   comparisons** pass.
4. **`33bffd4` — reuse decorative transitions.** Weather scrolling and the Wi-Fi
   advanced-pane transition use the existing `InteractiveBehavior`, now exported
   for these real consumers. Duration, easing and no-animation policy are
   unchanged; focus indication remains outside decorative animation.

The full gate caught TypeScript/generated-JavaScript drift in the initial bar
slice, corrected in `d49d034`. The transition slice also needed an explicit module
export, caught by Qt execution. Focused lint/tests alone were not sufficient to
validate every packaging/generation boundary.

## Results

“Production” below means the configured Lens roots minus `tests/`; it deliberately
includes the development gallery and generated sources. Every added helper is
included.

| Metric | Before | After |
| --- | ---: | ---: |
| Cyclomatic sum | 7,438 | 7,394 |
| Cognitive sum | 9,035 | 8,993 |
| Function effort | 44,294 | 44,080 |
| Component effort | 40,789 | 40,659 |
| Mean locality | 75.43 | 75.45 |
| Mean leverage | 53.25 | 53.26 |
| Source LOC | 35,917 | 35,821 |
| Physical LOC | 40,350 | 40,250 |
| Normalized clone groups | 156 | 153 |
| Clone-covered lines | 2,249 | 2,208 |
| `property var` | 425 | 424 |
| Unknown-signal suppressions | 3 | 3 |
| Lint-disable directives | 19 | 19 |

Locality/leverage aggregates are **essentially flat**, not a major architecture
improvement. Weather rail locality improves **76 → 79**, network details **41 →
44**. Their leverage scores decline **46 → 44** and **31 → 30**, respectively,
with the added dependency. `InteractiveBehavior` consumers increase **6 → 8**;
its leverage score was already capped at 100. The overall rounded score stays 83.

`DisplayController.edit` cognitive/effort falls **20/71 → 15/58**, with cyclomatic
unchanged at 12. The old output projection had cyclomatic/cognitive/effort
**7/19/65**. Its replacement projection is **7/12/50**, plus the collection method
**1/0/4**: the extra function is counted, and combined cyclomatic complexity rises
by one even though nesting and effort fall.

Including analyzed QML tests, source LOC is **41,654 → 41,576**, physical LOC
**46,376 → 46,294**, cognitive **9,267 → 9,226**, cyclomatic **7,819 → 7,777**,
function effort **48,574 → 48,378**, and clone-covered lines **2,837 → 2,796**.

Tracked `qml/js/ts/mjs/py/sh/nix/rs` physical lines, including canonical TypeScript,
generated JavaScript and tests outside Lens roots, fall **52,185 → 52,111**
(**−74**). Tests grow by **27 physical lines**. Including changed JSON/qmldir
metadata, the non-documentation diff is **−67 lines**. Markdown adds review
history; total repository text is not claimed to shrink.

## Validation and remaining findings

- Strict native Qt 6.11.1 lint: **366/366 discovered files**, zero diagnostics.
- **211 Qt passes**, zero failures/skips; shared-runtime smoke passes.
- TypeScript regeneration/currentness, Node presentation checks, Material
  regeneration/contrast/gallery checks and the full sibling-aware
  `local-build.py check . --keep-going --print-build-logs` gate pass.
- Lens contract: **warn**, zero verified or semantic failures, 907 review findings,
  one skipped optional check. Both parser oracles pass. Residual evidence includes
  25 formatting drifts and a benchmark-noise warning; this is not a clean audit.
- Profiler observations cover **245/314 QML files**, not statement/branch coverage.
- Six cleanup findings concern Material palette roles. Some foregrounds are read
  through data-driven tests; the coherent palette interface is retained rather
  than trimmed to satisfy heuristic reachability. No unused IDs/components are
  reported. Dynamic loader/process boundaries and legitimate JSON data properties
  retain their existing types and justified suppressions.

Further controller ownership work remains possible. Short coherent functions
such as Bluetooth's remembered-audio merge were not split merely to reduce a
nesting score. Similar-looking option tables were not merged across unrelated
domains. No live services were deployed/restarted and no hardware-latency or
compositor acceptance claim is made.

## Local evidence and reproduction

Ignored artifacts:

- `target/lens-post-material/baseline.tar.gz` and `after-tools/`.
- `../qmlqualitylens/target/shelllist-maintenance/material-{before,after}*.json`.
- `../qmlqualitylens/target/shelllist-maintenance/snapshot.mjs` and
  `bar-indicators-differential.cjs`.
- `/tmp/shelllist-lens-{dead-code,display,bar,behavior}-tests.log`.
- `/tmp/shelllist-lens-post-material-full-check-retry.log` and
  `/tmp/shelllist-lens-post-material-tools.log`.

From `shelllist/`:

```sh
python3 ../daemon-framework/tools/local-build.py develop . --command bash -c \
  'node tools/build-typescript.mjs --check && tests/run-qmllint.sh && tests/run-qml-tests.sh && tests/run-runtime-smoke.sh'
python3 ../daemon-framework/tools/local-build.py develop . --command \
  node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
python3 ../daemon-framework/tools/local-build.py check . --keep-going --print-build-logs
```
