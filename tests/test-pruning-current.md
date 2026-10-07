# Current test-pruning review

## Baseline and counting

The baseline is the working tree at the start of this request, including incoming
uncommitted test changes. `target/test-pruning-current/incoming.patch` and
`incoming-index.patch` preserve that starting state. The pruning commit includes
both this pass and the earlier, overlapping test-pruning edits already present in
the baseline (including the inventory counter and JavaScript tests). The counts
below measure this pass, not the combined commit against its parent. Unrelated
`.gitignore`, `flake.nix`, keyboard-contract edits and staged documentation
deletions are excluded from the commit.

The unchanged mixed inventory counts JavaScript assertion sites, Qt behavioral
cases (data rows individually), Rust/Python tests and daemon contract suites.
Lifecycle hooks are excluded. The explicitly acknowledged, pre-existing software
renderer skip remains counted, but is not executed coverage.

- Baseline: **365** units, including **295** Qt cases.
- Target: round(365 × 0.67) = **245** units.
- Result: **245** units, including **175** Qt cases; **120 removed**, **0 added**.
- **32.88% removed / 67.12% retained**. Qt cases alone declined by 40.68%.
- JavaScript 55, Rust 8, Python 2 and daemon contracts 5 are unchanged.

This is not a branch-coverage measurement. No discovery filter, counter change,
new skip or hidden/renamed test helper was used to reach the target.

## Selection rationale

1. Remove layout/token/wording snapshots and broad consumer matrices before
   shared interaction and domain safety tests. Retain representative narrow UI,
   painted field contrast and actual artwork loading/fallback.
2. Prefer one shared field transaction test over the same key sequence repeated
   in every wrapper. Keep domain-specific leases, acknowledgement, failed drafts,
   retries, cancellation, secrets, stale identities and uncertain outcomes.
3. Reduce repeated malformed-payload, icon-candidate and cache invalidation rows.
   Keep representative invalid identity/ownership, stale epoch/revision,
   privacy/hide invalidation, bounded cache and failed-draft behavior.
4. Remove duplicate presentation helpers and implementation-specific proofs such
   as exact feedback-cache eviction and assertions that a retired owner property
   does not exist. Do not alter production implementations to satisfy the count.
5. Preserve unique checks inside related retained workflows: media preferences
   still require pin acknowledgement and cannot replay on restoration; panel
   Previous remains usable after changing bar mode; focus-policy changes remain
   blocked by dirty layouts, trials and disconnection; pending category saves
   reject late dropdown activation.

Deleted suites: `ImageAssets`, `ListAlignment`, `SurfaceOutline`,
`MediaPresentation`, `NotificationActions`. SVG loading remains exercised by
actual media/notification artwork. Sender action classification remains in
JavaScript and the expanded-message Qt workflow. Geometry smoke, shared command
menus and native media targeting remain. Only the deleted notification-actions
Lens entrypoint was removed; Qt discovery itself is unchanged.

## Changed Qt suite counts

| Suite | Before | After |
| --- | ---: | ---: |
| ApplicationActions | 15 | 10 |
| ApplicationDetails | 6 | 2 |
| ApplicationResources | 8 | 2 |
| ApplicationSettings | 4 | 2 |
| BalancedDashboard | 9 | 3 |
| BarOsdResponsiveness | 2 | 1 |
| BatterySuspend | 4 | 3 |
| BluetoothRecovery | 10 | 9 |
| ChooserKeyboard | 3 | 2 |
| ChooserMemory | 9 | 4 |
| ClipboardPreview | 17 | 9 |
| CompactFields | 3 | 1 |
| ContentState | 8 | 1 |
| DaemonSessions | 3 | 2 |
| Displays | 17 | 13 |
| DomainWorkflows | 2 | 1 |
| ImageAssets | 1 | 0 |
| IpFields | 6 | 4 |
| ListAlignment | 1 | 0 |
| MaterialBar | 5 | 3 |
| MaterialFeedback | 3 | 1 |
| MaterialFields | 2 | 1 |
| MediaChip | 4 | 3 |
| MediaPresentation | 5 | 0 |
| MediaSources | 3 | 1 |
| NotificationActions | 1 | 0 |
| NotificationIcons | 10 | 4 |
| Notifications | 45 | 19 |
| ResultListReactivation | 2 | 1 |
| SurfaceActions | 6 | 3 |
| SurfaceOutline | 1 | 0 |
| SystemChoosers | 10 | 7 |
| WifiOperations | 17 | 13 |
| WifiPortal | 14 | 11 |

Other suites are unchanged by this pass. In particular, shared field interaction,
clipboard recovery, Wi-Fi prompts, authoritative work-area geometry and native
reduced-motion failure recovery remain.

## Deliberate reductions in direct evidence

There is less direct coverage of exact header/bar alignment, overflow ordering,
battery fill pixels, light-theme field pixels, exhaustive media identity/timing
formatting, adapter-specific empty-state wording and service icon selection.
The JavaScript material contrast matrix still covers both themes across 150
seed/mode combinations; one representative Qt painted-theme matrix remains.

Also reduced: basic successful memory restoration, repeated consumer tab/draft
transactions, separate cancellation-forwarding wrapper assertions, Bluetooth
restore-name composition, numeric focus-setting widget wiring, drag interruption
variants and duplicate refresh/error/schema combinations. Shared contracts and
representative domain tests are not proof that every removed branch remains
covered. Add a focused regression if these boundaries develop a meaningful bug.

Notification hierarchy, passive Read navigation, restored artwork hints,
expanded-only actions, page/reply transactions, immutable message identity,
atomic refresh failures, generation/revision fencing and live-update draft focus
remain under actual Qt tests. Native/protocol, retry and safety coverage took
priority over visual and implementation-specific matrices.

## Validation and reproduction

Final: **258 Qt passes, 0 failures, 1 unchanged renderer skip**: 174 executed
behaviors and 84 lifecycle hooks. All 16 behavioral JavaScript scripts, 8 Rust
tests, 2 Python tests, QML lint and native offscreen runtime smoke pass.

The five daemon contract suites were retained, not rerun. Full sibling-aware Nix,
live hardware/compositor and RHI acceptance were not performed. Runtime smoke
reported the offscreen plugin's unsupported-window-mask warning, not a failed
assertion. An initial generic Node invocation omitted required fixture arguments;
the corrected run uses each script's arguments from `flake.nix`.

From the matching development environment:

```sh
bash tests/run-qmlquality-tests.sh -o /tmp/pruned-qml.log,txt
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
bash tests/run-qmllint.sh
bash tests/run-runtime-smoke.sh
python3 -m unittest discover -s tests -p 'test_*.py'
# Node script arguments are declared in flake.nix.
# Run cargo test --offline --locked --manifest-path for each owned Cargo.toml.
```

Local evidence: `target/test-pruning-current/{before-qml.log,final-qml.log,
final-inventory.json,final-lint.log,final-behavior.log,final-rust.log,
final-smoke.log}`. The local environment wrapper and font configuration used for
Qt are the same as the baseline. Do not use older `after.json`/`after-qt.log`
artifacts in that directory as this pass's result.
