# Expressive maintenance review — 2026-09-28

These measurements describe the archived maintenance snapshot **before** the
subsequent contained-Tab/tonal-focus feature changes, not the combined current
tree. The original patch is retained at
`target/contained-focus/maintenance-baseline.patch`.

## Baseline and method

Baseline: `44584dbd8f9c91b6f48f8c2dd1850f000861bbd1`. Both measurements use
local qmlqualitylens 0.5.0, commit
`80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`, and Qt 6.11.1.
The unchanged configuration SHA-256 is
`25ed258faf45a547b55e581a1c92a75ad6d8e11805284c8763567cecbebadacb`.
No thresholds, roots, dynamic edges, suppressions or tests were removed/relaxed.

Structural snapshots disable external execution; native execution evidence is
collected separately on both trees. Production means configured roots excluding
`tests/`, including generated code and the gallery. Complete clone scans use
200,000 keys, 1,000 windows/key and 10,000 groups, with **zero omissions**.
The normal capped audit clone report is partial, not the source of these totals.

## Delivered changes

- **Shared ordinary focus identity.** `FocusLocations` now owns sensitive-field
  exclusion, registered-control classification and unique-key resolution for
  list/header and details navigation. Wi-Fi, Bluetooth, Clipboard, Applications
  and Audio/Media/Tray inherit the same resolution rule. Visibility traversal,
  browse/editor eligibility, generation fences and domain effects retain their
  existing owners. Duplicate or missing keys do not select an arbitrary target;
  disabled duplicates remain ambiguous. Sensitive/revealed credentials cannot
  acquire a restorable key.
- **Typed host/domain references.** Five registry controller references, three
  bar controller/state references and the toast reply-state reference now have
  concrete QML types: nine actual QObject `var` escape hatches removed. JSON
  payloads remain data, not pretend QObject types. The bar's private resident-host
  boundary remains dynamic; the host is not an exported QML module.
- **Presentation reuse and bounded cleanup.** Activity previews reuse the same
  `NotificationAppIcon` and notification unwrapping as history/toasts, retaining
  transparent previews and their two-pixel inset. Removed the unused Wi-Fi name
  forwarding method/import, obsolete bar playback-cycle wrapper and two unused
  IDs. The daemon's cycle operation is not removed. Palette and platform-mock
  contracts were not deleted merely because Lens cannot resolve every use.
- **Bar dispatch.** Surface-opening routes share one path; timezone aliases the
  time/weather route and existing no-argument effects reuse their owning methods.
  Unknown/prototype-property keys now return false without calling anything.
  Valid routes retain their effects and handled-return semantics, including when
  a backend operation returns false. Domain recovery machines are unchanged.
- **Initial-layout restoration race.** Full validation exposed a baseline race:
  incubated controls could exist while their page still had zero content height,
  and a queued initial scroll restore could overwrite an unrecorded reveal.
  Details navigation now retains restoration until page layout is ready; callbacks
  consult current pending state rather than retaining an old target. Explicit
  reveal commits layout/scroll bookkeeping first. Existing interaction, context
  and invocation cancellation remain authoritative; no timer or polling was added.

A media descriptor rewrite was evaluated but not retained: its small complexity
improvement cost duplicated descriptor fields in canonical/generated sources.
No TypeScript or generated-media change is included in the final patch.

## Measurements

| Production metric | Before | After |
| --- | ---: | ---: |
| Cyclomatic sum | 8,000 | 7,987 |
| Cognitive sum | 9,479 | 9,467 |
| Function effort | 46,536 | 46,473 |
| Component effort | 43,504 | 43,445 |
| Mean locality | 75.9253 | 75.9359 |
| Mean leverage | 53.9253 | 54.0605 |
| Source LOC | 37,003 | 36,968 |
| Physical LOC | 41,462 | 41,430 |
| Normalized clone groups | 137 | 136 |
| Clone-covered lines | 1,969 | 1,957 |
| `property var` | 435 | 426 |
| Unknown-signal suppressions | 0 | 0 |
| Lint-disable directives | 15 | 15 |

These are **modest improvements**, not a major architectural or performance gain.
FocusLocations leverage rises **59 → 74**; NotificationAppIcon **64 → 79**.
GlanceNotificationsCard component effort falls **283 → 241**, BarController
**396 → 378**. Added shared responsibilities have costs: FocusLocations effort
**138 → 140**, DetailFlickable **152 → 155**, DetailsNavigation **737 → 738**.

Including analyzed tests: cyclomatic **8,559 → 8,549**, cognitive
**9,767 → 9,756**, function effort **52,034 → 52,000**, component effort
**52,113 → 52,086**, locality **77.2216 → 77.2305**, leverage
**50.6557 → 50.7605**, source LOC **44,521 → 44,517**, physical LOC
**49,275 → 49,274**, clone groups **179 → 178**, covered lines **2,631 → 2,619**.

Tracked `qml/js/ts/mjs/py/sh/nix/rs` physical lines, including tests and generated
sources outside Lens roots, are **54,560 → 54,559: one line saved overall**.
Tests grow by 31 lines. Documentation/evidence is not counted as code; total
repository text is not claimed to shrink. The rounded score remains **83**.

## Validation and limitations

- Final sibling-aware full gate passes, including **282 Qt passes / 200 behavioral
  cases**, strict lint, runtime/gallery smoke, TypeScript currentness, contract
  checks and sibling packages. Native lint reports **388/388 files**, no diagnostics;
  both parser oracles pass.
- Two early full-gate attempts failed the existing browse-scroll assertion. The
  untouched baseline reproduced it on focused run 8. An initial bookkeeping-only
  fix was insufficient; tracing exposed the separate zero-height layout race.
  The deterministic regression fails without either part of the final fix. After
  both fixes, **12 consecutive focused suites pass (32 cases/hooks each)**, as do
  the final full gate and Lens-driven suite. No original assertion was weakened.
- Recording-stub differential checks preserve **18 bar route traces** and reject
  four prototype-key routes without effects. A frozen-input media comparison also
  passes, but the final media implementation is unchanged, so that comparison is
  not evidence of a retained media refactor.
- Lens verdict remains **incomplete**, not clean: baseline/current qmlformat
  cannot format `tests/qml/imports/Quickshell/Services/SystemTray/SystemTrayItem.qml`.
  Formatting drift stays **73 → 73**. Final verified/semantic failures are zero;
  review findings **996 → 993**. Unused IDs **2 → 0**, unused components remain zero.
  Six palette and four mock-boundary cleanup candidates remain; the existing
  SpringAnimation resolution limitation remains despite clean native lint.
- Profiler/benchmark evidence is offscreen and has no matched performance baseline;
  it is not a latency, statement-coverage, GPU or live compositor acceptance claim.
  The independently reproduced historical Displays teardown warning is not claimed
  fixed. Nothing was deployed or restarted.

## Local evidence

- `target/lens-expressive-maintenance/{baseline.tar,before-tools/,after-tools/,differential.cjs}`
- `../qmlqualitylens/target/shelllist-maintenance/expressive-{before,after}*.json`
- `/tmp/expressive-{full-gate,full-gate-retry,full-gate-complete,complete-tools}.log`
- `/tmp/expressive-focus-shelllist-expressive-baseline-8.log`
- `/tmp/expressive-{scroll-red,layout-red,scroll-complete-1,scroll-complete-12}.log`
- `/tmp/expressive-final-qml.log`

Reproduce with `daemon-framework/tools/local-build.py check shelllist --keep-going
--print-build-logs` from the Projects directory. In the matching development
environment, run `tests/run-performance-benchmarks.sh` followed by local Lens
`measure all --config qmlqualitylens.config.json`; inspect its contract verdict,
not just the command's exit status.
