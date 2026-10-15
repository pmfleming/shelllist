# Test pruning — baseline `c4bd285`

## Scope and accounting

The starting worktree was clean after the five quality-improvement commits. A
fresh matching Qt run and source archive are under ignored
`target/test-pruning-c4bd285/`. This is a new baseline, not the previous 618-unit
checkpoint. The established mixed counter is unchanged: JavaScript assertion
sites, Qt behavioral cases/data rows, Rust/Python tests and daemon-contract suites.
Lifecycle hooks and loop iterations are not additional units. Inventory is not
coverage; the existing software-renderer skip is inventory, not executed evidence.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion sites | 71 | 68 | 3 |
| Qt behavioral cases/data rows, including existing skip | 355 | 212 | 143 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **441** | **295** | **146** |

`round(441 × 0.67) = 295`: **33.11% removed, 66.89% retained**. Twelve Qt suites
and their unused helper declarations were deleted; 52 remain. No production,
runner, counter, import-mock, producer-fixture or build-check changes. Lens loses
only four explicit entrypoints for deleted files; discovery roots/exclusions are
unchanged. No hidden/renamed tests, new skips, data filtering or scenario repacking.

The case-set comparison finds exactly **143 removals, zero additions**. All **196
other retained Qt test bodies are byte-for-byte unchanged**. The sole modified
retained body drops a fixed nine-method cardinality assertion from GeneratedContracts;
it still validates every discovered method's requests, replies and missing fields.
The three JavaScript removals are two stack-preview field assertions duplicated
by native member deletion, and an exact chart interpolation midpoint. Native
member identity, source immutability, power gaps/zero and signed areas remain.

## Decisions and retained owners

- **Shared interaction first:** retain native text/choice drafts, incoming-source
  isolation, save/discard/blur, forward/reverse wrap, live rollback, switch arrival,
  removed/hidden editors, result arrows and modal/command containment. Remove a
  forward-disabled-field permutation; reverse hide/skip and removal remain. The
  shared dropdown test keeps deferred clicks; Applications retains the actual
  save-on-click/acknowledgement/retry exception. Keep sensitive-field memory
  exclusion and asynchronous navigation/closure/readiness fences; remove repeated
  fallback contexts and a Loader-internal completion probe.
- **Prefer behavior owners over repeated DTO matrices:** keep real application
  query and push/gap completion, unknown Close/placement, action target ownership,
  read-only status recovery, malformed reads and reopening fences. Remove repeated
  settings/history/window DTO plumbing and status presentation checks. Node's
  complete selected App/Bar schema/fixture loops remain; native GeneratedContracts
  retains one control-family engine check rather than repeating those loops.
- **Bar/media:** keep acknowledged workspace activation, unknown battery readings,
  verified brightness/profile readbacks, native compositor/work-area consumers,
  domain-local gap bursts, newer pushes and process-generation fencing. Native
  SystemChoosers retains explicit player targets, busy/capability guards, field
  transactions, Audio acknowledgement and live tray/native-menu ownership. Remove
  stream/property tables, duplicate generic error/reconnect permutations, passive
  media-enrichment/icon suites, workspace reveal/monitor-layout checks and OSD
  paint/error presentation. The existing RHI-only artwork skip remains counted.
- **Power safety:** retain hardware-limited protection, calibration readback and
  restoration failure, uncertain writes/explicit retry, newer threshold drafts,
  status timeout/owner loss, cancellation not rollback, full sleep lifecycle,
  uncertain execution and lost-reply recovery. Native critical-policy review,
  independent retry, battery-retarget cancellation and degraded Keep awake
  release remain. Remove repeated ordinary policy/alert/opcode outcomes and
  per-consumer power-mode, linked-field ordering, chart-range and status paint.
  Pure battery guards still cover both threshold/alert domains and unsafe commands.
- **Displays:** keep opaque-mode local drafts, unsafe/last-screen guards, native
  reference commands, cancelled drags, mirroring/Preview, docking hardware wait,
  manual/failure recovery, baseline availability, trial expiry/topology and
  close-time reversion. Remove valid-drag-versus-button geometry duplication,
  repeated docking/snapshot matrices, passive focus-availability combinations and
  compact-dialog shape. JavaScript retains all directional/layout safety checks;
  native failed rollback, uncertain confirmation and lost revert remain.
- **Bluetooth/Clipboard:** keep pairing secrets/queue/captured replies, partial
  profile success, failed rename drafts, adapter saved-field transactions and
  partial/malformed/lost acknowledgements. Remove signal paint/draft repetition,
  final-message/error-owner permutations and policy-reset wiring. Clipboard keeps
  private/stale preview fences, native leases/save, revision-scoped deletion and
  wipe consent, paging failure/retry, captured commit failure after navigation,
  paste preparation/publication/reopened-session guards and fresh-lease conflict
  recovery/discard. Remove warm-cache/layout/invalidation repetitions, another
  Escape-discard path and equivalent success/session variants. Node retains
  revision-checked bulk deletion and background annotation.
- **Notifications:** retain actual policy transactions, unselected-app and expanded
  member deletion identities, malformed counts, late consent cancellation, atomic
  windows, stale/foreign replies, queued revisions and native group/cursor reads.
  Keep reply/reused-ID ownership, obsolete preparation, duplicate completions,
  cancellation isolation, and error/newer-event operation snapshots. Remove simple
  DND/reply repetitions, ordinary query/error/ack variants, exact period/header
  presentation and pixel-offset restoration. Pure projection tests retain order,
  closed/superseded windows and input immutability.
- **Wi-Fi:** keep real credential input/expiry, saved-profile SecretAgent flow,
  delivery/persistence distinction, pending-read draft preservation, reveal failure
  and foreign-secret rejection, owner-scoped status/cancellation, bounded recovery,
  QR credential non-retention and explicit portal claims/no replay. Reduce method
  metadata and credential-order permutations, duplicate reveal/disconnect/error
  routes, successful portal argv checks and process-adapter internals. Portal URL
  mismatch and unowned/late replies remain; native Rust retains literal argv,
  URL/deadline/workspace validation. Typed Forget, pairing passkey validation and
  remote-owned display remain; service-consent layout repetition is removed.

## Changed Qt suites

Counts include retained data rows and exclude lifecycle hooks. Unlisted suites
are unchanged; zero means the suite was actually deleted, not excluded.

| Suite | Before | After |
| --- | ---: | ---: |
| ActivityContract | 5 | 3 |
| ApplicationActions | 14 | 10 |
| ApplicationContract | 4 | 1 |
| ApplicationDetails | 3 | 2 |
| ApplicationResources | 2 | 0 |
| BalancedDashboard | 4 | 2 |
| BarControlContract | 9 | 3 |
| BarDomainRecovery | 7 | 4 |
| BarOsdResponsiveness | 1 | 0 |
| BarReadContract | 6 | 0 |
| BarSessionControlContract | 5 | 1 |
| BatteryContract | 13 | 9 |
| BatteryPresentation | 8 | 4 |
| BatterySuspend | 2 | 1 |
| BluetoothRecovery | 15 | 10 |
| ChooserMemory | 7 | 3 |
| ClipboardPreview | 5 | 2 |
| ClipboardRecovery | 19 | 13 |
| CompactConfirmations | 5 | 4 |
| DaemonBridge | 6 | 4 |
| DisplayContract | 8 | 5 |
| Displays | 24 | 15 |
| FieldInteraction | 13 | 11 |
| GeneratedContracts | 5 | 1 |
| IpFields | 4 | 3 |
| MaterialFeedback | 1 | 0 |
| MaterialFields | 1 | 0 |
| MediaSources | 1 | 0 |
| NotificationActionContract | 14 | 10 |
| NotificationCenter | 12 | 9 |
| NotificationIcons | 2 | 0 |
| NotificationQueryContract | 6 | 3 |
| Notifications | 11 | 7 |
| ProviderShortcuts | 1 | 0 |
| ResultListReactivation | 1 | 0 |
| SleepContract | 10 | 6 |
| SurfaceRegistry | 4 | 2 |
| SurfaceShortcuts | 2 | 0 |
| SystemChoosers | 6 | 5 |
| TimeWeatherLocations | 1 | 0 |
| TimezoneClock | 3 | 1 |
| WifiCasting | 3 | 2 |
| WifiOperations | 27 | 14 |
| WifiPortal | 10 | 7 |
| WifiRequestMetadata | 17 | 8 |
| WifiScannerContrast | 1 | 0 |

## Deliberate evidence gaps

There is less direct evidence for individual endpoint/error wiring, every bar
stream, per-panel restoration/field composition, resource range interactions and
paint, native IP Copy/read-only geometry, notification scroll offsets/empty-period
presentation, warm-cache performance/eviction, Bluetooth signal/reset presentation,
time/weather sorting and clock offsets, disabled field/scanner paint, screenshot
and global shortcut routing, OSD presentation and passive media enrichment.

Shared transactions, model tests and daemon contracts do **not** prove every
removed consumer path or permutation. The visual/interaction and domain safety
contracts are unchanged; there is no claim of identical branch coverage. Add
focused regressions when needed: **295 is not a permanent cap**. No hardware,
compositor, RHI, camera, IME or human screen-reader acceptance was performed.

## Validation and reproduction

- Full native Qt: **315 passed, 0 failed, 1 unchanged renderer skip** (211 executed
  behaviors plus 104 excluded lifecycle hooks), versus baseline **482/0/1**.
- Strict lint, all 17 JavaScript suites, source-relative imports, two Python tests
  and native offscreen runtime smoke pass. Palette contrast retains 150 seed/mode
  combinations; it is not a replacement for removed scanner/field pixel tests.
- Four Rust search tests pass locked/offline. Portal's four tests pass against
  unchanged source in an isolated copy with an offline-regenerated temporary lock
  and the current framework dependency. The repository's unchanged portal lock
  cannot run `--locked`; no repository lock was modified. This is not locked
  portal release/build acceptance.
- Full current-source `local-build check . --offline --keep-going` is **blocked**
  before snapshotting by an unrelated untracked file in sibling `daemon-framework`:
  `docs/reviews/test-reduction-2026-10-15.md`. That worktree was not altered, added
  or ignored. All five daemon contract gates remain unchanged but were not rerun;
  no successful full sibling/release check is claimed.

Evidence includes `before.json`, `final.json`, matching Qt logs, `baseline.tar`,
`plan.json`, `case-diff.json`, `retained-bodies.json`, `preservation.json`, JS/lint/
Python/Rust/smoke logs and the external Nix blocker in `target/test-pruning-c4bd285/`.

```sh
QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh > /tmp/pruned-qml.log 2>&1
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
tests/run-qmllint.sh
# After the sibling owner resolves its unrelated untracked-file blocker:
local-build check . --offline --keep-going
```

Previous review: `git show c4bd285:tests/test-pruning-current.md` (618 → 414).
Historical checkpoints are not current acceptance or future test-count caps.
