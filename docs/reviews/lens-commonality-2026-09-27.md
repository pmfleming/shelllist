# Bounded frontend commonality review — 2026-09-27

## Scope and comparison

- Baseline: `624681d515df1984aeccb8bebb6206c4100e8b08` (outlined fields).
- Validated implementation: `d5f0e60e40d5e74ff8637891f5ece2293145435a`.
- Local QML Quality Lens: `80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`, v0.5.0.
- Unchanged configuration SHA-256:
  `bcda687a06197dfc08fbd16e66a2c99d77a3914ef6f5790d482c44d2cde952e3`.

Fresh before/after runs use the same roots, entrypoints, dynamic edges, thresholds
and suppressions. Structural snapshots disable external execution; configured
`measure all` runs collect separate native execution evidence. No tests were
removed or skipped. Prior maintenance/pruning measurements are separate baselines.
Metrics are heuristics, not correctness, coverage or elapsed engineering effort.

## Changes and ownership

1. **Provider projection:** `Core.Provider.makeResult` owns identity, priority and
   existing model normalization. Wi-Fi, Bluetooth, clipboard, applications and
   displays supply domain fields. Wi-Fi/Bluetooth/application/display batches use
   shared `resultsFor` and override `resultFor`; clipboard retains its offset-aware
   history scoring. Dynamic actions, stable payloads and domain controllers stay
   separate. Three now-unused provider IDs and four forwarding mappers disappear.
2. **Cancellation:** application/clipboard query and detail callers now use the
   same `DaemonBackend.cancel` contract already used by Wi-Fi and subscriptions.
   A new native test exposed an existing bug: an omitted typed `string` parameter
   becomes the literal `"undefined"`, yielding `consumer-N::undefined` instead of
   the intended cancellation ID. Separate typed `cancel(requestId)` and
   `cancelWithId(requestId, cancellationId)` entrypoints fix it without adding a
   dynamic argument escape hatch. Bluetooth/clipboard operation IDs remain
   explicit; routing ownership, empty-request rejection and no-replay rules stay.
3. **Bluetooth presentation:** extract one audio descriptor projection into the
   existing `BluetoothFlow` helper. The controller still accumulates repeated
   device keys sequentially, retains presentation across reconnects, owns live
   routes, and prunes forgotten devices. Remove duplicate resets already performed
   by `invalidateBluetooth`; draft rejection still occurs first.
4. **Bar cleanup:** derive the stream-to-property lookup from the existing semantic
   stream aliases instead of maintaining fourteen duplicate assignments. Remove
   unused `brightnessSet`/`notificationsTogglePanel` aliases and Bluetooth's unused
   `protocolDescribe` alias after consumer search. Generated protocol capabilities
   remain intact; this does not remove daemon operations.
5. **Typed boundaries:** Activity, Battery and BatteryEnergy backends now require
   their actual controller types, matching the five main domain adapters. JSON
   payloads and deliberately lazy surface-registry handles remain dynamic.

The stale commonality document described an untyped `endpoint` property removed
by `4d5ff24`; it now describes the actual typed transport fields. No descriptor
escape hatch was reintroduced merely to shorten adapter declarations.

## Measurements

Production scope is configured QML/JS roots excluding `tests/`, including shared
helpers, the gallery and generated Material/TypeScript outputs.

| Metric | Before | After |
| --- | ---: | ---: |
| Cyclomatic | 7,407 | 7,403 |
| Cognitive | 9,001 | 8,990 |
| Function effort | 44,128 | 44,086 |
| Component effort | 41,065 | 41,000 |
| Mean locality | 75.2841 | 75.2841 |
| Mean leverage | 53.0886 | 53.1181 |
| Source LOC | 36,060 | 36,026 |
| Physical LOC | 40,511 | 40,479 |
| Clone groups | 156 | 156 |
| Clone-covered lines | 2,226 | 2,226 |
| `property var` | 424 | 421 |
| Unknown-signal suppressions | 3 | 3 |
| Lint-disable directives | 19 | 19 |

These are **small improvements**, not a broad architecture transformation.
Locality and production cloning do not improve. Provider leverage changes:
Wi-Fi **30→31**, Bluetooth **19→21**, clipboard **45→47**, applications **11→13**;
all retain locality 100. Shared Provider and DaemonBackend already score 100 for
both locality/leverage, with unchanged consumer counts of 8 and 14. Their own
component effort increases **62→83** and **343→347**: extraction costs are included.

`applyAudioSnapshot` cyclomatic/cognitive/effort changes **10/20/65→4/3/18**;
its new helper contributes **7/11/38**, so combined values are **11/14/56**.
Combined cyclomatic increases by one, despite lower cognitive/effort estimates.

Including analyzed QML tests: source LOC **41,197→41,215**, physical LOC
**45,900→45,922**, cyclomatic **7,761→7,760**, cognitive **9,200→9,189**, function
effort **47,918→47,914**, component effort **46,827→46,811**. Mean locality
**77.1118→77.0990**, leverage **50.6869→50.6901**, clone groups **193→192**,
clone-covered lines **2,799→2,777**, `property var` **451→449** (the cancellation
fixture adds one). The all-source locality regression is not hidden.

The broader tracked `qml/js/ts/mjs/py/sh/nix/rs` physical-line count, including
canonical TypeScript, generated outputs and all tests, is **51,390→51,428 (+38)**:
non-test code **−16**, tests **+54**. Thus the requested **total LOC reduction is
not achieved** in this slice. Documentation adds further lines outside that code
count. No total-repository shrink claim is made.

Both expanded clone scans are complete at **200,000 keys / 1,000 windows per key /
10,000 groups**, with zero omitted windows/groups. Default configured clone
reports are capped and are not used for this comparison. Normalized matches such
as the Bluetooth login-state/device-list segmented controls share structure but
not option policy; no artificial component was extracted to erase those matches.

## Validation and residuals

- Strict native lint: **365/365 files**, zero diagnostics.
- Qt: **118 behavioral cases / 188 passes including hooks**, no failures/skips.
  Added provider identity/non-mutation/override and cancellation identity tests;
  existing recovery, drafts, secret handling, display preview/revert, pagination,
  reply focus and keyboard tests remain.
- Current-source sibling-aware Nix gate: **all checks passed**, including protocol
  contracts, TypeScript generation, packaging, palette/gallery checks and smoke.
- **50,000 seeded differential audio snapshots** match the baseline (including
  duplicate keys and empty/missing profile data), with inputs unchanged. All
  fourteen Bar stream mappings/subscriptions and payload mappings also match.
- Parser oracles pass. Lens stays **warn**, score **84**, zero verified/semantic
  failures, review findings **916→911**, one optional skipped check.
- Formatting drift **31→31**; benchmark noise warning remains. Profiler observes
  **233/313 QML files**, not statement/branch coverage. Six palette-role cleanup
  findings remain review candidates, not proven removable API. No unused component
  or ID findings before or after.

The first generation check caught an edit to generated `BluetoothFlow.js`; the
helper was moved into canonical `typescript/bluetooth/BluetoothFlow.ts` and
regenerated before successful validation. The cancellation test failed before the
boundary fix; its expected IDs were not weakened. A differential harness VM setup
error was corrected before collecting the successful comparison.

Wi-Fi prompt/secret generation, Bluetooth operation recovery, clipboard leases
and terminal-event handling, application history consistency and bar OSD outcomes
remain domain-owned. Do not merge them into a generic lifecycle state machine for
metric gains. No live deployment, service restart or hardware acceptance occurred.
Unrelated changes in sibling `daemon-framework` tooling were left untouched.

## Evidence and reproduction

Ignored local evidence: `target/lens-commonality-current/` contains the baseline
archive/revision/config hash, `before-tools/`, `after-tools/`, and
`differential.cjs`. Structural snapshots and complete clone reports are under
`../qmlqualitylens/target/shelllist-maintenance/commonality-{before,after}*`.
Snapshot collection preceded the implementation commit, so its revision metadata
still names the baseline; the measured after-source is the implementation above.
Logs: `/tmp/shelllist-commonality-{tests,full-check,after,differential}.log`.

```sh
python3 ../daemon-framework/tools/local-build.py develop . --command bash -c \
  'node tools/build-typescript.mjs --check && tests/run-qmllint.sh && tests/run-qml-tests.sh && tests/run-runtime-smoke.sh'
python3 ../daemon-framework/tools/local-build.py check . --keep-going --print-build-logs
python3 ../daemon-framework/tools/local-build.py develop . --command \
  node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
```
