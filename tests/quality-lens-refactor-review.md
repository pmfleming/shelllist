# QML Quality Lens refactoring review — 2026-10-24

## Scope and findings

Measured the incoming working tree at `e06b9b5`, using the local
`../qmlqualitylens/dist/bin/qmlqualitylens.js` (0.5.0), Node 24.16.0 and the
unchanged `qmlqualitylens.config.json`. This is a bounded first pass, not a claim
that all requested project-wide metrics improved.

1. **Ordering complexity:** `DeltaCursor.accept` duplicated baseline checks in
   nested subscription/epoch branches. It now names same-source/same-epoch state,
   rejects duplicates before checking continuity, and has one invalidation path
   for ordering failures. Recovery, safe integers and exact rollover remain.
2. **Compatibility indirection:** four fields used `SettingRow`, whose colour
   comparisons inferred feedback semantics. They now use `FormField` directly;
   the unused wrapper/export is removed. The lid field explicitly owns warning
   text/tone. Bluetooth retains its existing Help allocation.
3. **Dynamic dispatch:** provider lookup returns `Provider`, not an untyped value.
   Dispatch checks live next to execution rather than in a single-use helper
   returning either a provider or `false`. Screen geometry reads typed
   `ShellScreen` properties instead of arbitrary string-key property lookup.
4. **Dead seams:** removed unused `ResultStore.applyBatch`/`Model.resultBatch`,
   two command-menu forwarding methods, `ActionDetailsPane.bodyHeight`, unused
   solar-noon metadata and two unused IDs. Production uses the existing normalized
   batch path; no caller was migrated around validation. Kept enum-only SystemTray
   `Status`, whose apparent unreachability is not proof of dead code. Also kept
   property-held Binding/ActionControl objects and change-handler-backed state.
5. **Small duplication:** selection restoration has one call after typed native
   focus dispatch, instead of a copy in each text/IP branch.

## Measurement

Artifacts and logs: ignored `target/lens-refactor-review/{before,after}/`.
Production below excludes `tests/` and `dev/` only in the comparison; Lens itself
still analyzed its unchanged full configured scope, including generated code.
Function totals sum Lens's per-function/handler advisory metrics, **not** Halstead
vocabularies or an estimate of developer hours.

| Metric | Before | After |
| --- | ---: | ---: |
| Production source lines | 39,882 | 39,811 |
| Full configured source lines, including new tests | 48,889 | 48,868 |
| Production function/handler cyclomatic sum | 9,255 | 9,247 |
| Production function/handler cognitive sum | 6,501 | 6,491 |
| Production function/handler weighted effort sum | 40,683 | 40,616 |
| `DeltaCursor.accept` cyclomatic / cognitive | 25 / 32 | 24 / 23 |
| `DeltaCursor.accept` maximum nesting | 3 | 1 |
| `DeltaCursor.accept` weighted effort | 129 | 104 |
| `DeltaCursor.accept` Halstead effort | 31,747.56 | 31,184.45 |
| `ProviderRegistry` function cognitive / effort sums | 35 / 210 | 32 / 192 |
| Direct observed `FormField` uses | 51 | 54 |
| Unused-ID findings | 2 | 0 |
| Total findings | 951 | 946 |

Overall score remains **83**; leverage **33**, duplication **95**, cognitive **98**,
complexity **94** and effort **84** are unchanged. Rounded locality is **77 → 76**
(raw component mean **76.584 → 76.499**): removing a high-scoring wrapper and adding
registry test bindings outweigh small consumer improvements. This is not a measured
project-wide locality win. Direct shared composition and fewer dispatch indirections
improve ownership locality, but broader decomposition remains follow-up work.
Screen lookup removes dynamic access but adds two cognitive points in its explicit
geometry expression; that tradeoff is included, not hidden by extraction.

Clone detection is **partial**, capped at 100 groups; omitted groups change 61 → 65.
There is no demonstrated overall clone-count reduction. Many retained findings are
normalized literal tables, imports or test scaffolding rather than equivalent
behavior. No exclusions, suppressions, thresholds or generated sources were changed.

## Interaction contract and validation

Use `FormField.label` and explicit `statusText`/`statusTone`, not the retired
`SettingRow.title`/subtitle-colour adapter. Fields keep the same editor objects,
accessible names, guards and browse/edit transactions. This is a composition
refactor, not a key-model change. The local keyboard/convergence documents were
updated without undoing their pre-existing staged deletions.

- Strict `tests/run-qmllint.sh`: pass.
- Full `tests/run-qml-tests.sh`: **357 passed, 0 failed, 1 existing skip**.
- Added native lid Home/Escape/Tab transactions, provider rejection/dispatch checks,
  and malformed baseline/rollover recovery cases. No tests removed or new skips.
- `tests/run-runtime-smoke.sh`: pass; offscreen plugin reports its window-mask
  limitation. Not live compositor, hardware, IME or screen-reader acceptance.
- `python3 tests/review-panel-ui.py --base HEAD`: four composition prompts,
  zero new wrappers or numeric-style prompts; contained identities retained.
- `git diff --check`: pass. Full Nix/package and sibling-daemon checks not run.

Remaining high-value review candidates include `UpdateController.finishHistory`,
notification publication and large multi-purpose chooser views. Their ownership
and stale-reply guards need dedicated changes, not indiscriminate helper extraction.
Existing `.gitignore`, flake, performance-lens edits and staged documentation
removals are outside this refactor and were preserved. Nothing was committed.
