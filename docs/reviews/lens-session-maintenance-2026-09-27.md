# Post-session shared-UI maintenance — 2026-09-27

Baseline: the **working tree**, not clean HEAD `1a9209084e7780934542194f015200432ad529ff`.
The pending invocation-focus implementation is included on both sides and was
preserved before refactoring as `target/lens-session-maintenance/baseline.tar`
and `baseline.patch`. These measurements must not be compared directly with the
[earlier keyboard baseline](lens-keyboard-maintenance-2026-09-27.md).

Analyzer: local QML Quality Lens `80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`,
v0.5.0; native Qt 6.11.1. Configuration SHA256 remains
`3c4b4d9c563e364dcbf6bd95655a22966ddd1acefe0d8b523d495bb619eabe2f`.
No source roots, thresholds, entrypoints, suppressions or test discovery rules
changed. No tests were removed or skipped.

## Kept changes

- **Shared settings descriptors:** `Core.Model.settingToggle`, exposed through
  `ModelApi`, normalizes keep-open settings toggles for Wi-Fi and Bluetooth.
  Checked values, capability guards, visibility, destructive tone and disabled
  reasons remain provider-owned; it neither caches capabilities nor sends actions.
- **Shared details routing:** `ActionDetailsPane` dispatches header intent through
  its overridable `triggerAction` method. Applications, Wi-Fi, Bluetooth and
  Displays use the controller default. Clipboard retains its specialized routing,
  including draft-aware paste, image/link guards and busy-operation ownership.
  Consumers must override the method rather than add a second signal dispatcher.
- **Restoration simplification:** `ChooserSession.apply` computes the matching
  details context once, sharing the browse-while-refreshing and ready-editor paths.
  Pending state, cancellation, selection restoration and generation fencing stay
  intact. Remove a redundant reset already performed by `cancelSessionRestore`.
- **Presentation commonality:** Applications filters one tab descriptor list with
  the controller's existing allowed-tab policy. When no application is selected,
  that policy exposes only the application tab; unavailable detail content stays hidden.
  Seven page loaders use QML's implicit Component wrapping without changing
  asynchronous loading, active predicates, geometry or lexical context. Shared
  theme tokens replace four copies of the bar group background/border expressions;
  this is not a bar redesign.
- **Typed/public host API:** `placementScreen` is a `ShellScreen`; native
  `frameSwapped` connects through the visual item's public `Window.window`, not
  Quickshell's private `_backingWindow`. Both unknown-signal suppressions and one
  missing-property suppression disappear. Screenshot placement calls the existing
  window-X method directly; remove its redundant alias, a single-use Wi-Fi
  connection forwarder, and one genuinely unused geometry-test ID.

Domain recovery, credentials, leases, request IDs, generated protocol code and
sensitive-dialog handling were deliberately not consolidated. Remaining unused
palette roles are API candidates, not proven dead code.

## Measurements

Production is the configured non-test component/source slice, including generated
outputs. All-analyzed includes QML tests. Component use counts are taken from the
whole configured graph, so production leverage also reflects test consumers.
Shared helper/API costs and new tests are included; no new component was extracted.

| Metric | Production before → after | All analyzed before → after |
| --- | ---: | ---: |
| Cyclomatic | 7,831 → 7,824 | 8,337 → 8,335 |
| Cognitive | 9,337 → 9,333 | 9,606 → 9,604 |
| Function effort | 45,876 → 45,820 | 50,998 → 50,978 |
| Component effort | 42,821 → 42,707 | 50,771 → 50,719 |
| Mean locality | 75.4440 → 75.4585 | 76.5077 → 76.4923 |
| Mean leverage | 53.5415 → 53.6534 | 50.4830 → 50.5418 |
| Source LOC | 36,833 → 36,755 | 43,822 → 43,797 |
| Physical LOC | 41,347 → 41,270 | 48,621 → 48,598 |
| Complete clone groups | 154 → 150 | 195 → 191 |
| Clone-covered lines | 2,142 → 2,107 | 2,777 → 2,742 |
| `property var` | 426 → 425 | 455 → 454 |
| Unknown-signal suppressions | 2 → 0 | 2 → 0 |
| Lint-disable directives | 16 → 15 | 16 → 15 |

Broader tracked `qml/js/ts/mjs/py/sh/nix/rs` code, including policy tests:
**54,124 → 54,119 lines (−5)**. Documentation and ignored evidence scripts are
outside this count. Thus total code barely falls after adding regression tests;
this is a small maintenance improvement, not a major reduction. Expanded clone
scans use identical limits (200,000 keys / 1,000 windows per key / 10,000 groups),
with zero omitted windows/groups. Capped default clone reports are not used here.

`ChooserSession.apply` cyclomatic/cognitive/effort falls **19/22/94 → 17/20/84**.
Not every local metric improves: `ActionDetailsPane` takes on routing work,
`ModelApi` gains an export, and Theme owns two more tokens. The new native tests
increase their components' dependencies, slightly **lowering overall locality**.
Lens also flags the Applications tab-filter binding and the expanded native smoke
handler for review. These are retained rather than hidden behind suppressions.

## Validation and limitations

- Warning-fatal native lint, runtime smoke, **177 behavioral cases / 253 Qt
  passes including hooks**, JavaScript model checks and the full sibling-aware
  co-development gate pass. The new tests check one-time default routing,
  actual Clipboard specialization/guards, unchanged bar colors, and native
  `frameSwapped` delivery through the public visual-window attachment.
- **20,000 seeded Wi-Fi/Bluetooth action projections** match the saved baseline
  without input mutation. **All 6,144 restoration-state traces** match, including
  readiness, suspension, missing lists, context/key changes and pending state.
  These pure comparisons supplement, not replace, native focus/recovery tests.
- Lens stays **warn**, score **83**; audit review findings remain **977**, with
  no blocked checks. Parser diagnostics remain zero. Unused-ID findings fall
  **1 → 0**, unused components remain zero, six palette-role candidates remain.
  Formatting drift stays **48 → 48**, with no formatting errors. No new formatting
  debt or suppression was accepted.
- Profiler-observed QML files were **270/323 → 269/323** in the final runs (an
  earlier after-run observed 271). These asynchronous execution observations are
  neither statement/branch coverage nor a deterministic coverage percentage.
  Lens still lacks the built-in `SpringAnimation` type; native lint is clean.
- The previously reproduced baseline Displays engine-teardown warning was not
  observed in this pass's normal/full-gate logs; no fix or suppression is claimed.
  Live layer-shell placement/input masks, compositor behavior, hardware IME,
  screen readers and hardware performance remain separate acceptance work.
  Nothing was committed, deployed or restarted by this maintenance pass.

## Evidence and reproduction

- `target/lens-session-maintenance/{baseline.tar,baseline.patch,baseline-revision.txt}`
- `target/lens-session-maintenance/{before-tools,after-tools}/`
- `target/lens-session-maintenance/differential.cjs` (extract the baseline archive
  into `/tmp/shelllist-session-refactor-baseline`, then run it from the repo root)
- `../qmlqualitylens/target/shelllist-maintenance/session-{before,after}*`:
  static reports, summaries and complete clone scans without execution evidence
- `/tmp/shelllist-session-refactor-{before-tools,after-tools,after-static,tests,smoke,differential,full-check}.log`

Use the [quality gate guide](../qml-quality-review.md) with the same local Lens,
Qt environment and sibling worktrees on both sides. The initial invocation-focus
work remains uncommitted alongside this refactor.
