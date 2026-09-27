# Test pruning — 2026-09-27

Baseline: clean Shelllist `2961774a89752d040109057e3ac1f66e6d35861d`.
This is a fresh baseline after the Material and maintenance work, not the
357 → 239 inventory from the previous review. Target:
`round(298 × 0.67) = 200`.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper call sites | 152 | 81 | 71 |
| Executed QML behavioral cases, including data rows | 135 | 108 | 27 |
| Rust tests | 4 | 4 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Combined inventory units** | **298** | **200** | **98** |

**32.89% removed; 67.11% retained.** These are the established mixed inventory
units, not independent scenarios, runtime assertion invocations or a coverage
percentage. The counter is unchanged. QML lifecycle hooks are excluded:
runner totals **211 → 174** include **76 → 66** hooks. Native behavioral cases
alone fell 20%; JavaScript assertion sites fell 46.71%.

Infrastructure gates remain additional to this inventory: packaging/imports,
module evaluation, native lint, TypeScript and generated assets, deterministic
performance, sibling compatibility, resource fixtures and native hypridle
readiness. Sibling repositories and their tests were not pruned.

## Decisions and remaining owners

| Removed or narrowed | Retained owner / rationale |
| --- | --- |
| Bar/weather/battery presentation catalogues and standalone Bluetooth battery helpers | Native bar responsiveness, brightness failures, media interaction and Bluetooth aggregate-earbud rendering remain. Exact glyph thresholds, wording, weather artwork and battery presentation ranges no longer have dedicated helper checks. Generated TypeScript currentness still covers every bar module, but is not a behavioral substitute. |
| Display snapping/option catalogues, exact validation wording/precedence, grouped-settings duplication and narrow inspector geometry | JS retains exact advertised modes, rotated/scaled and finite geometry, malformed/invalid inputs, empty/duplicate/all-off rejection and invalid mirror sources/cycles. Native tests retain draft-only edits, mirror promotion, acknowledged settings, stale identities/topology, preview tokens, confirm/revert and pending-close recovery. |
| Battery temporary-operation timer bookkeeping, some transport-error classifications, invalid-policy variants, charge-card placement/title scenarios and chart helper coordinates | Device identity/replacement races, autosave exclusion, command guards, uncertain outcomes, stale telemetry, critical protection and actual daemon wire names remain. Native profile keyboard/accessibility and independent notification flags remain. Charts retain real isolated 0/100% pixels, gap rendering, explicit inspection/Escape, invalid charge samples, backwards clocks, signed-power areas and late-cache protection. |
| Serialized-model representation/no-rewrite assertions, generic delegate identity and simple result-store/reactivation duplicates | Native notification actions still exercise QVariant/Repeater data; live replies retain their focused delegate through a 205-record burst. Keyed models retain adversarial string identities and stale queued-work cancellation. Hidden/reopened list replacement and progressive selected-row visibility regressions remain. Intermediate chunk-size observations were also removed without changing the retained case count. |
| Notification active/history filtering and origin-navigation fixtures; separate standard-action keyboard/layout case | Reply acknowledgement/failure, newer draft survival, catch-up, transport recovery, DND, adversarial identities and shared quick-action keyboard/pointer/disabled behavior remain. The removed filtering/navigation scenarios are not claimed to be covered by these other cases. |
| Bluetooth global list-preference/empty-settings fixtures, duplicate offline audio-policy variant and lifecycle helper variants | Pairing request identity/input recovery, rename/adapter acknowledgement and failure, opaque routes, apply-before-remember identity, failed profile saves, unavailable/disconnected route guards and scoped resets remain. Global list preferences and empty-list settings navigation lose their dedicated view tests. |
| Dedicated shared-detail and launcher layout suites; todo button-wrapper fixture; solar/lunar/hourly weather cases and tiny-screen geometry | Shared activation/accessibility, immediate focus, native work-area updates/disconnect, negative-origin placement and same-index city replacement remain. Clock-driven solar/forecast updates, lunar metadata, todo-specific keyboard wiring and generic wrapping/stacking no longer have dedicated cases. They remain product behavior, not obsolete requirements. |
| Application-history target/range stale-reply examples, clipboard tab-draft duplicate, screenshot status expiry and Wi-Fi merge/enable variants | History retains pagination, sliding windows, committed-cursor retry, overlap deduplication and nonadvancing-cursor termination. Daemon generation/request fencing, clipboard failed drafts/leases/conflicts and destructive no-replay/revision guards remain. Wi-Fi retains delta precedence, secret schemas, explicit sharing/late-secret fencing, disabling persistence and partial-save recovery. Generic boundary checks do not replace history-specific target/range switching coverage. |
| Extra Material reference vectors/theme-policy cases, timezone SVG row, resource availability observations and network notification helper variants | Qt retains exact foreground bindings and seed/mode reactivity; Node retains contrast across 150 seed/mode combinations. Gallery mode/font smoke and reproducible palette/timezone generation remain. One real SVG decode case, native resource gaps/null-versus-zero handling and daemon-recommended network failure classification remain. Desktop fallback/override policy and duplicate-notification variants lose direct assertions. |

Four behavioral JS files were deleted: `check-bar-presentation.js`,
`check-battery-presentation.js`, `check-bluetooth-battery.js` and
`check-weather-presentation.js`. Their flake invocations were removed;
the surviving battery-history check now has its own descriptive name.
Unused Display/Flow command arguments and test-only fixtures were removed.

Five QML suites were deleted: `tst_activity_keyboard.qml`,
`tst_application_page_layout.qml`, `tst_detail_layout.qml`,
`tst_profile_gaps.qml` and `tst_weather_forecast.qml`. Only those five deleted
entrypoints were removed from the Lens configuration; production analysis
roots, discovery rules, exclusions and quality thresholds are unchanged.

No tests were skipped or renamed out of discovery. The retained Wi-Fi case
was renamed to describe its remaining disable row. Assertions were not moved
into uncounted helpers or repackaged to hit the target. Both whole scenarios
and redundant observations within retained scenarios were removed.
Version-specific compositor dispatch and daemon protocol compatibility tests
remain because they protect supported wire boundaries, not merely historical
implementation shapes.

**Tradeoff:** less helper, intermediate-state, visual-layout and optional
presentation coverage, including some unique consumer scenarios listed above.
Shared contracts do not prove every deleted variation. This is not a claim of
unchanged line/branch coverage or measured runtime improvement. Production
implementation, canonical/generated sources, protocol fixtures, lockfiles,
Rust/Python tests and all five daemon contract suites are unchanged.

## Validation

- Baseline: **135 Qt behavioral cases**, zero failures/skips (211 with hooks).
- Retained: **108 Qt behavioral cases**, zero failures/skips (174 with hooks).
- Strict QML lint and runtime smoke pass; both Python profiler tests pass
  separately with `python3 tests/test_profile_qml.py`.
- Full sibling-aware Nix gate: **all checks pass**, including cached results,
  retained Node suites, Rust tests, five daemon contracts, packaging,
  module evaluation, TypeScript currentness, Material generation/contrast and
  both gallery modes, timezone assets and deterministic performance.
- The Nix log contains a Fontconfig default-config notice, Qt's locale fallback,
  the `homeManagerModules` unknown-output warning and expected negative-test
  application errors. No test failure was suppressed to obtain the result.
- No live hardware/compositor acceptance, deployment or service restart occurred.
  Unrelated sibling worktree changes were left untouched.

## Reproduce

Ignored evidence is under `target/test-pruning-20260927/`:
`baseline-revision.txt`, `before-qml.log`, `before-counts.json`,
`after-qml.log`, `after-counts.json`, `python-tests.log`, `full-check.log`
and `final-check.log`.
The baseline log was captured before editing; use matching source/log pairs:

```sh
python3 tests/count-test-inventory.py --revision 2961774 \
  --qml-log target/test-pruning-20260927/before-qml.log

python3 ../daemon-framework/tools/local-build.py develop . --command bash -c \
  'tests/run-qmllint.sh && tests/run-qml-tests.sh && tests/run-runtime-smoke.sh' \
  > target/test-pruning-20260927/after-qml.log 2>&1
python3 tests/count-test-inventory.py \
  --qml-log target/test-pruning-20260927/after-qml.log

python3 ../daemon-framework/tools/local-build.py check . \
  --keep-going --print-build-logs
```

On a fresh checkout, recreate the baseline log by running its native tests in a
separate worktree at `2961774`; do not combine today's source counts with that
baseline's Qt log. The inventory script rejects incomplete, failed or skipped
Qt runs. New files must be Git-added before the local-build snapshot gate.
