# Application frontend acceptance — W1-APP

Implementation checkpoint, not integration, quality completion or rollout approval.
Bridge remains default; no wire API, limit, service/startup or generated contract changes.

## CQ-15 contract

`ApplicationOperations.start` captures `params.action` as `request.operationAction`.
The same captured native action validates target/action/operation receipts and
classifies active/terminal Close no-handoff behavior. Presentation no longer
classifies `close-window-` command IDs; lifecycle no longer remaps those IDs after
submission. Provider command-to-native mapping remains at the submission boundary.
Native revision checks, retained outcomes, owned read-only recovery, captured view
identity, explicit retry and authoritative catalog replacement remain unchanged.

The existing `tst_application_actions.qml` suite has one data-driven extension for
Close/CloseWindow: closed/still-open/unknown/missing/malformed observations and
failed/cancelled terminals; irrelevant launch receipts; foreign action/target/ID;
owned status completion after browsing/closing/reopening; late/duplicate outcomes;
no optimistic removal/dismissal and explicit retry. Existing row-focus and
missing-revision/quiet-terminal tests remain, rather than another parallel suite.

## Private native routing contract

The existing `socket::native_quickshell_app_socket_acceptance` retains its ordinary
pass, then reuses `socket::payload::large_catalog` for one near-16 MiB UTF-8 result
through real Quickshell 0.3.0 and production `DaemonBackend`/shared session/socket
routing. Two frontend consumers deliberately reuse local request ID `read`.
The healthy consumer performs eight small reads, keeps its subscription baseline,
renews independently after large delivery, and completes a final small read.
A separate real-socket owner also retains its original subscription across the
native run, then reads successfully and cancels that exact subscription.
The large consumer checks protocol/version, row/generation identity and every
UTF-16 unit of the producer's `é🦀` UTF-8 fixture, including its ASCII tail.
Generated request/event validation is enabled; no frontend limits are bypassed.
`AppApi` exposes aliases to those same generated validators through the existing
Launcher module, avoiding Quickshell's outside-config-root relative-script ban.
There is no copied validator or native-test-only policy implementation.

No payload is rendered, retained in root state, stringified or logged. Synthetic
comment sizing preserves the existing 64 KiB headroom below the 16 MiB service
result limit; the input/output limits are not raised. Captured child diagnostics
are capped at 32 KiB per stream. QML has a 15-second deadline; the child has the
existing 20-second producer-fixture deadline and kill-on-drop ownership.

Safety: actual app process with private HOME/XDG, no-host-activation D-Bus, private
catalog, mock compositor and fake handoffs. Frontend buses are unavailable and its
XDG paths are private. The test asserts no fake launch occurred. No host catalog,
windows, applications, clipboard, notifications, hardware or manager is exercised.

This adds native frontend **routing**, not whole-panel maximum rendering, a new
framing ceiling, sustained-load evidence, a process-crash journey or performance/
peak-memory proof. Existing exact socket/bridge/D-Bus and one/two-worker stalled
reader cases are prerequisites, not new achievements of this checkpoint.

## Reproduction and results

Run from this frozen family, through
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh timeout 1800`.
Use the family's `daemon-framework/tools/local-build preflight` and `develop` for
matching sibling snapshots/dev shells; Git-add new inputs before capture.
Never run native QML standalone against a host producer.

Task root:
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/06-application-frontend`.
Exact drivers/logs remain there. From `worktrees/`, invoke the helper above with:

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh
# Original frontend checks; native entrypoint was subsequently fixed/revalidated.
"$CHECK" timeout 1800 bash ../check-frontend.sh
# Ordinary Rust/retained payload checks; original native import failure retained.
"$CHECK" timeout 1800 bash ../check-producer.sh
# Full Qt, source capture, build-input/surface and sibling Nix checks.
"$CHECK" timeout 1800 bash ../check-integration-inputs.sh
# Final Qt/lint/contracts/Clippy and three private native repeats.
"$CHECK" timeout 1200 bash ../check-native-retry.sh
```

| Gate | Result / log |
| --- | --- |
| Actual Qt actions / stream recovery | 23 / 5 passed; `frontend-implementation.log`; final actions rerun: 23 passed, `native-retry.log` |
| Full Qt, development and sibling Nix | Both **469 passed, zero failed, one existing renderer skip**; `integration-inputs.log` |
| QML lint / generated contracts | Strict full QML plus explicit native entrypoint lint and generated-contract negatives/parity pass; `native-retry.log` |
| Rust ordinary debug | 46 library + 17 session passed; `producer-implementation.log` |
| Retained boundary regressions | Explicit exact-result/+1 unit case and all four payload cases pass, including one/two-worker stalled readers; `producer-implementation.log` (prerequisites, not new achievements) |
| Rust formatting / Clippy | `cargo fmt --check` and all-target/all-feature `-D warnings` pass, including final rerun; `native-retry.log` |
| Native Quickshell | Three passes, each ordinary + large modes; full UTF-8 comments **16,707,951 / 16,707,950 / 16,707,950 bytes**, result ceiling **16,777,216**; `native-retry.log` |
| Matching sibling Nix | `buildInputs`, `appDaemonContract`, `qmlTests` pass; release producer: 46 library + 17 session passes; `integration-inputs.log` |
| Build-input / surface checks | `cargo xtask build-inputs` and `cargo xtask surfaces --check` pass; `integration-inputs.log` |
| Task-local shell / recipe | Four task drivers and documented release recipe pass `bash -n`; release recipe not executed |

No new skips were added. Real-systemd, release-only profiling and unrelated
explicit-only cases remain unrun; the assigned native/payload cases were invoked
by name, never a blanket ignored-test run. Expected malformed-event diagnostics
remain in the Qt logs.

### Source and binary provenance

Original baselines: app `0e6de17f7d60c619dd12795def6f2ecd0bb75ba2`, frontend
`6f14ede26d27cff03b72e51f647ee5e96dba6928`; framework `563e7f9` unchanged.
Paired producer implementation: `b76bc159392eb9e1103cf31fcae198cfd4ff112c`.
Rust/Cargo 1.95.0; Qt 6.11.1; Quickshell 0.3.0. Native app/test executables are
fresh family **debug** builds, not original-checkout or installed daemon binaries.

All eight changed executable inputs exactly match the persistent sibling capture
at task `artifacts/implementation-snapshot/` (`sources.json` and `.approval-root`);
only this evidence file was updated after checks. App store source:
`/nix/store/w1sl4z5fnz87k89akhqjxwxd93j5706y-source`. Full sibling/store maps and
Nix derivation identities are retained in `integration-inputs.log`.

| Executable | SHA-256 |
| --- | --- |
| `app-daemon/target/debug/app-daemon` | `5bfb28d1942c2e074c5db079eb45793bc8b959115d59a5f5824216d47ed1657c` |
| `app-daemon/target/debug/deps/session-5389fcdbf844b90e` | `b70466eee35be0247a0a784cc58887b2a5d92121295742816c4ad265ee9bde77` |
| Quickshell Nix wrapper | `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980` |
| Quickshell wrapped ELF | `d6b3de984d553cf9f398e7621a1f02231e5f5d34f44e40981cb7e95f5335d428` |

Quickshell executable directory:
`/nix/store/nm6wrf4gprrxlri8nr16kcmixpkk8hrf-quickshell-0.3.0/bin/`.
Final Git commits and the complete source inventory are in task REPORT/result.

### Retained failures

- `frontend-attempt1.log`: task driver initially ran from the family directory
  rather than `shelllist/`; corrected cwd, rerun passed. No functional pass is
  attributed to that attempt.
- `producer-implementation.log`: ordinary native startup initially failed with
  `qrc:/qs-blackhole`, before large delivery. Quickshell disallows the relative
  generated-JS import outside the entrypoint configuration root, despite static
  QML lint accepting it. The fixture now imports the existing Launcher module;
  AppApi aliases the same generated validators. Final strict/native runs pass;
  no shared-client defect, validation bypass or limit increase was needed.

## Deferred serial release recipe

After quality and coordinator integration, reserve an exclusive shared-lock window
with **no other workers/builds**. First reproduce release correctness from the
family root (not a performance run):

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh
"$CHECK" timeout 1800 nix develop ./daemon-framework --no-update-lock-file --command bash -c '
  set -e
  ./daemon-framework/tools/local-build preflight ./shelllist
  cd shelllist
  ../daemon-framework/tools/local-build develop . --command bash -c '\''command -v quickshell'\'' > "$ORCHESTRATION_TASK_DIR/release-quickshell.txt"
  cd ../app-daemon
  ../daemon-framework/tools/local-build develop . --command bash -c '\''
    set -e
    export SHELLLIST_SOURCE="$(realpath ../shelllist)"
    export SHELLLIST_QUICKSHELL="$(< "$ORCHESTRATION_TASK_DIR/release-quickshell.txt")"
    cargo build --locked --release
    cargo test --locked --release --test session socket::native_quickshell_app_socket_acceptance -- --ignored --nocapture --test-threads=1
    sha256sum target/release/app-daemon "$SHELLLIST_QUICKSHELL"
  '\''
'
```

For the subsequent separately queued measurement, capture/preflight one complete sibling tuple;
rebuild `app-daemon --release` and matching Quickshell/frontend inputs, hash source
snapshots, daemon, session-test and Quickshell binaries. Run the same private
Session adapter, catalog byte count, one/two-worker configurations and read/
subscription/renewal/status/cancel mix for bridge and socket serially. Specify
warmup/sample counts before measurement; collect p50/p99 and daemon + frontend +
retained bridge child process-tree RSS/PSS/private memory, marking unavailable
metrics explicitly. The native correctness test above is not a benchmark recipe
execution or evidence of whole-desktop savings. Packaged startup, mismatch,
upgrade/rollback, broken-pipe/effect-receipt loss and rollout remain separate gates.

Mandatory Rust/QML Lens review/refactor is a separate exact-session continuation;
this implementation checkpoint does not claim it has completed.
