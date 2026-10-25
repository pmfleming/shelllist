# Quality Lens refactoring campaign

Baseline: `606b93631ada767d8ca69470a733f2c5651d9a2c`.
Static comparisons archive both commits and use one frozen evaluator and unchanged
`qmlqualitylens.config.json`. Scores are advisory, not behavior or productivity proof.
Raw local evidence is in the sibling Lens checkout's `target/shelllist-campaign/`.

## Remove unused internal presentation/state

Removed the unused `ApplicationPresentation.cpuText` / `memoryText` functions and
their private number helper. Application resources use their existing resource
presentation owner instead. Removed VPN's write-only `connectingUuid`; the request
ID still owns connection cancellation/completion. Tracked-source and test searches
found no consumers of these internal names. No provider/model API, IPC entry point,
compatibility behavior or test owner was retired.

Qt 6.11.1, offscreen/software, matching qtsvg plugin: baseline and this change each
pass **419 checks, zero failures, one existing renderer skip** (counts include
lifecycle hooks). No tests were changed. Initial baseline SVG failures were resolved
by supplying the environment's matching SVG plugin, not by suppressing assertions.
Hardware mutations, live compositor, IME and human accessibility remain untested.

## Bluetooth snapshot boundaries

Moved radio/audio wire-shape predicates to the existing `BtApi.js` owner and
separated snapshot completion from mutation completion in `BluetoothBackend`.
Both adapter and device lists reuse the same keyed-item predicate without creating
a concatenated list. Removed the scan-response forwarding wrapper. The backend
still owns error presentation and synchronous publication; `SnapshotCursor` still
advances only after successful publication. Loading/unavailable handling, protocol
checks, independent audio/radio watermarks and mutation reconciliation are unchanged.

Extended the existing native stream-recovery journey with malformed adapter/audio
rows; rejected rows do not consume the subsequent valid revision. Full Qt suite:
**419 passed, zero failures, one existing renderer skip**. Strict `qmllint` passes
for the changed Bluetooth/VPN QML against real Quickshell/Qt import metadata.
