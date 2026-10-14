# Test pruning — baseline `46407b7`

## Scope and accounting

This pass uses Shelllist's existing mixed inventory, not sibling repositories or
an older pruning target. The working tree was clean at `46407b7`; the matching
baseline Qt log is the successful architecture-closure run. Source and log were
saved before pruning in `target/test-pruning-46407b7/`. Incoming changes in
`update-daemon` are unrelated and were not edited.

`tests/count-test-inventory.py` is unchanged. It counts JavaScript assertion
sites, Qt behavioral cases/data rows, Rust/Python tests and five daemon contract
suites. Lifecycle hooks, helper-loop iterations, build scripts and sibling tests
are not additional units. **This is an inventory reduction, not a coverage
percentage.** The existing software-renderer skip remains inventory, not executed
coverage.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion sites | 68 | 66 | 2 |
| Qt behavioral cases/data rows, including existing skip | 535 | 333 | 202 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **618** | **414** | **204** |

`round(618 × 0.67) = 414`: **33.01% removed, 66.99% retained**.
Two presentation-only suites were deleted, leaving 64 Qt suites. No runner,
discovery, counter, fixture, build-check or production changes; no filters,
renamed/hidden tests, new skips or repacking removed scenarios into loops.
Retained parameter rows still count separately. The two removed JavaScript
assertions fixed generated method counts at eight and nine, unnecessarily
rejecting API growth; all schema/fixture validation loops remain.

## Review decisions

### Prefer behavior owners over opcode matrices

- **Generated contracts:** keep all five native validator cases and Node
  request/result/event validation, invalid payloads, nullability and exact-integer
  checks. The underlying coverage is still app's eight methods and selected nine
  bar methods, not complete schemas for all five daemons. All native producer
  fixtures and all five daemon contract gates remain unchanged.
- **Bar controls/session:** remove repeated ordinary success, diagnostic strings,
  preference/playback opcode variations and backend-only UI test calls. Keep
  clamped audio/brightness, input rejection, brightness-error OSD, degraded
  profile telemetry, selection result, seek/mode rejection and representative
  timeout/disconnect no-replay checks. Native SystemChoosers, MediaChip and
  BalancedDashboard still test actual command activation and acknowledgement.
- **Battery/sleep:** keep hardware-limited outcomes, settings/inhibition/calibration
  errors, newer threshold/alert drafts, explicit retry, cancellation not rollback,
  status timeout, owner loss, stale terminal state and failed calibration
  restoration. Sleep keeps failed versus unknown execution, a complete lifecycle,
  lost-reply recovery, policy failure, and critical cancellation that cannot undo
  dispatched sleep. Remove repeated command-success, terminal-label and
  action × reconnect-stage rows. JavaScript safety/capability/identity tests and
  native degraded-release, critical-protection and calibration-consent tests stay.
- **Display/activity:** keep uncertain confirmation, failed revert, authoritative
  policy result, recovery, expiry, rollback failure, stale drafts and close-time
  revert. Native Displays retains enable/disable/confirm/revert, last-screen and
  mirror safety, drag cancellation, opaque modes, docking/focus acknowledgement
  and retries. Activity retains refresh progress, read/validation errors,
  destructive uncertainty and late-range fencing, rather than every todo opcode.
- **Notifications:** sample policy/preparation/record failures and preserve reply
  timeout/reconnect drafts, reused IDs, event-before-ack, duplicate completion,
  obsolete preparation and cancel acknowledgements. Native notification suites
  retain DND/reply success/failure, policy transactions, record/app-scoped deletion,
  malformed consent, late preparation, atomic paging and stale ownership. Remove
  repeated ordinary acknowledgements, transport rows and equivalent invalid-page
  variants; keep staged-continuation failure and stale-cursor restart coverage.
- **Bar reads:** sample the generic stream map and gap recovery rather than every
  property. Keep actual producer work-area/compositor projections, battery sleep
  policy and resident notifications. Unchanged BarDomainRecovery covers gap
  storms, independent recovery, monitor failure, stale replies and process loss.

### Remove duplicated or constraining native checks

- Remove per-surface construction/descriptor tables; domain suites still construct
  real panels. Registry keeps invalid IDs, startup selection, queued latest-request
  ownership and shared resident notification state. Shortcuts sample one lazy
  route while retaining registration/no-effect checks.
- Reduce Wi-Fi terminal-result and credential-order permutations. Preserve real
  credential input, expiry/clearing, receipt versus delivery/persistence, cancellation
  acknowledgement, bounded recovery, stale reads, explicit retry and no replay.
  Metadata tests still distinguish method/variant from misleading IDs, fail closed
  on unknown methods, protect secrets/reused IDs, isolate portal effects and clean
  up on rejection/transport failure.
- Reduce clipboard bulk-count, discard and malformed-paste variants; preserve
  revision-checked deletion/wipe consent, failed drafts, fresh leases, hidden paste
  ownership, navigation races, private cache handling and stale thumbnails.
  Bluetooth retains pairing secrets/queue ownership, partial outcomes, malformed
  and lost adapter acknowledgements, failed rename drafts and device-scoped policy.
- Remove battery card size/theme/layout matrices and duplicate focus/confirmation
  checks, chart pixel/legend/inspection checks, application header composition,
  resource presentation repetition, notification footer/geometry and clipboard
  preview-chrome constraints. Remove the standalone CompactFields and
  SharedPanelComposition suites. Shared native fields, multiline IP settings,
  modal/destructive workflows, painted field contrast, palette and chart-data
  tests remain. Unknown readings are still distinguished from measured zero.
- Sample chooser restoration contexts and reverse removal during Tab rather than
  every direction/context pair. Keep disabled/hidden traversal, external updates,
  draft discard, slider commit/live rollback, asynchronous focus, sensitive-field
  exclusion and modal containment. Remove duplicate clock-format checks while
  keeping the real clock button, fractional offsets and unavailable timezone.

## Changed Qt suites

Counts include data rows and exclude lifecycle hooks. Unlisted suites are unchanged.

| Suite | Before | After |
| --- | ---: | ---: |
| ActivityContract | 15 | 5 |
| ApplicationActions | 17 | 14 |
| ApplicationContract | 6 | 4 |
| ApplicationDetails | 3 | 2 |
| ApplicationResources | 3 | 2 |
| BarControlContract | 21 | 9 |
| BarReadContract | 23 | 6 |
| BarSessionControlContract | 22 | 5 |
| BatteryContract | 27 | 13 |
| BatteryHistory | 3 | 1 |
| BatteryPresentation | 15 | 8 |
| BluetoothRecovery | 17 | 15 |
| ChooserMemory | 10 | 7 |
| ClipboardPreview | 6 | 5 |
| ClipboardRecovery | 22 | 19 |
| CompactConfirmations | 6 | 5 |
| CompactFields | 1 | 0 |
| DaemonBridge | 7 | 6 |
| DisplayContract | 19 | 8 |
| Displays | 25 | 21 |
| FieldInteraction | 17 | 13 |
| MaterialBar | 2 | 1 |
| NotificationActionContract | 34 | 11 |
| NotificationCenter | 16 | 11 |
| NotificationIcons | 3 | 2 |
| NotificationQueryContract | 7 | 6 |
| Notifications | 13 | 11 |
| SharedPanelComposition | 1 | 0 |
| SleepContract | 27 | 10 |
| SurfaceRegistry | 19 | 4 |
| SurfaceShortcuts | 4 | 2 |
| TimeWeatherLocations | 2 | 1 |
| TimezoneClock | 4 | 3 |
| WifiOperations | 33 | 21 |
| WifiRequestMetadata | 12 | 10 |
| WifiScannerContrast | 2 | 1 |

## Deliberate gaps

There is less direct evidence for individual endpoint wiring, all bar stream
mappings, every error/transport combination, each generated surface factory,
chart paint/inspection, particular footer/preview layouts, notification toast
visibility, and per-panel focus variants. Shared handlers and native interaction
tests do **not** prove those removed permutations. Retained tests are not a claim
of identical branch coverage. Add focused regressions when necessary; **414 is
not a permanent cap**. No live hardware, compositor, RHI, IME or screen-reader
acceptance is claimed.

## Validation and reproduction

Passed: full native Qt **460 passes, zero failures, one unchanged renderer skip**
(332 executed behaviors + 128 excluded lifecycle hooks), strict QML lint, two
Python tests and native offscreen runtime smoke. The full current-source
`local-build check shelllist --offline --keep-going` also passed (exit 0), including
retained JavaScript/contract gates and regenerated producer-fixture checks. Its
isolated Qt run independently reports the same 460/0/1 result. Runtime smoke has
the existing offscreen window-mask warning, not a test failure.

Case-set comparison confirms **202 removed cases, zero added cases**; the inventory
is exactly 414. A source comparison also confirms 278 retained multiline test
bodies are unchanged: no assertion weakening or relocation into other scenarios.

Local evidence is under `target/test-pruning-46407b7/`: baseline/final sources,
`before.json`, `final.json`, `case-diff.json`, `preservation.json`,
`retained-bodies.json`, `final-qml.log`, `lint.log`, `python.log`, `smoke.log`,
`nix.log` and `nix-qml.log`.

```sh
local-build develop shelllist --offline --command bash -c '
  cd /home/laufan/Projects/shelllist
  QML_XHR_ALLOW_FILE_READ=1 tests/run-qmlquality-tests.sh > /tmp/pruned-qml.log 2>&1
'
cd shelllist
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
cd ..
local-build check shelllist --offline --keep-going
```

The preceding pruning report is historical and available as
`git show 46407b7:tests/test-pruning-current.md`; its 808 → 541 figures are not
this pass's baseline or result.
