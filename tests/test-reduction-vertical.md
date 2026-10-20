# Native-journey reduction pass — incomplete against the 33% target

## Result and fresh baseline

**The requested reduction is not achieved.** The fresh registered-suite inventory
is **994 → 988**, seven Qt cases removed and one real native journey added:
**six fewer cases (0.60%)**. The strict target is **665**; another **323 net
removals** would be required. This is not completion or acceptance of the original
instruction, and the earlier 1,029-test baseline is not reused.

| Repository | Baseline revision | Before | After |
| --- | --- | ---: | ---: |
| shelllist | e8fcff9 + incoming build-input edits | 348 | 342 |
| app-daemon | 9b82a80 | 60 | 60 |
| bar-daemon | 48a6a43 + incoming location/flake edits | 205 | 205 |
| bt-daemon | 54cf57a | 60 | 60 |
| clip-daemon | c78960b | 41 | 41 |
| nm-daemon | b7efa39 | 106 | 106 |
| update-daemon | 6020751 | 112 | 112 |
| daemon-framework | c0db05e | 62 | 62 |
| **Registered-suite scope** | | **994** | **988** |

Accounting is unchanged from the preceding review: Rust libtest entries including
existing ignores/features, Python test methods including hyphenated filenames,
Qt behavioral rows including the existing renderer skip, behavioral JavaScript
scripts and five daemon contract suites. Exclude lifecycle hooks, assertions,
subtests, repeated child-process executions and duplicate vendored source tests.
Separate VM/desktop acceptance, static packaging checks and manual captures remain
outside this measured scope and unchanged. Including those unchanged suites would
make the percentage reduction smaller, not rescue the target.

`count-ecosystem-tests.py` makes this existing convention reproducible in tracked
source. Fresh discovery and Qt baseline logs were collected before editing; the
archive includes the incoming worktree. The same Rust discovery applies before
and after because no Rust source, manifests or Rust tests changed in this pass.

## A real replacement owner, not another mocked controller test

`test-native-application.py` drives `e2e/application.qml` inside **Quickshell's real
engine**, with native mouse/keyboard input and production components:

1. Start a private D-Bus with no host activation directories, an actual app-daemon,
   the production JSONL bridge and the native search executable.
2. Search two real desktop entries through the Applications panel.
3. Open its Settings tab and save a category. A directory deliberately blocks the
   settings destination, so the actual daemon's atomic write fails. Verify the
   requested value is not published and retry remains available.
4. Remove only that fixture obstruction; explicitly save again, refresh the real
   catalog, and verify both the UI category and the durable settings file.
5. Launch through a controlled executable that fails once. Verify no dismissal or
   automatic retry; explicitly retry and require a successful handoff. Independently
   check that exactly two launcher invocations occurred.

Both bus addresses, HOME and all XDG roots are disposable. The daemon's PATH has
only fixture executables. No real graphical application, user service or compositor
is invoked. This does not prove systemd lifetime, compositor placement or hardware
behavior; those existing boundary tests remain.

Quickshell's Process plugin is statically linked, so qmltestrunner cannot load it.
QtTest is used as an input/assertion driver with automatic discovery disabled;
Python's registered unittest explicitly runs the journey, enforces a timeout,
requires a PASS marker and independently checks the filesystem effects. It cannot
pass merely because no Qt tests ran. No old test was renamed into an undiscovered
helper. `checks.nativeApplication` adds this runner to the mandatory Nix check set.

## Actual removals and retained protection

| Removed case(s) | Retained owner and deliberate tradeoff |
| --- | --- |
| ApplicationContract query/refresh fixture replay (1) | Native search, refresh and persisted-category journey; generated contract validation remains. The private optimization “unchanged revision causes exactly one request” is no longer frozen. |
| ApplicationSettings pointer save/ack/retry mock (1) | Native storage failure, explicit retry and durable acknowledgement. Keep the separate adversarial test for old replies and target-scoped feedback. Exact saved-choice decoration and no-op request counts lose direct assertions. |
| BarSessionControl seek/disconnect no-replay repetition (1) | Shared JSONL drain/exit tests, BarControl brightness/disconnect no-replay, and native media capability/target interactions remain. This removes a second consumer permutation of the same shared backend, not the transport's no-replay owner. |
| IpSettingsState manual configuration fixture (1) | The actual Advanced Settings DNS editing journey now checks its outgoing address, prefix, DNS search, routes, metric and DNS policy together. Invalid native input and write refusal remain there. The direct helper's repeated auto-DNS toggle is removed. |
| Wi-Fi metadata cache-refresh and portal rows (2) | Keep user-level refresh scheduling during connect and portal claim journeys, plus method-versus-ID classification, unknown method/prototype rejection, reused-ID ownership and rejected dispatch. Drop exact internal classification-table assertions for these routes. The refresh journey does not dispatch the identical cached-refresh variant: that execution-label permutation loses direct coverage; it is not claimed as a fully duplicated scenario. |
| Time & Weather normal/dark estimate row (1) | Identical interaction remains at minimum width/light palette. Do not repeat passive metadata/navigation assertions solely by theme. |

The unused 1,061-line session-control fixture, its generation/copy references and
three empty suites are deleted. Lens loses the removed IP-state entrypoint and
gains the native journey entrypoint. No discovery exclusions, new ignored tests,
coverage threshold changes, compatibility removals or production behavior changes.

## Validation

- Qt baseline: **393 passed / 0 failed / 1 existing skip**; final: **380 / 0 / 1**.
  Behavioral rows: **282 → 275**, lifecycle hooks **112 → 106**. Strict ordinary
  QML lint, native-journey lint and both native runtime smoke programs pass.
- The real application journey passes repeatedly (three consecutive final-stage
  runs plus a final rerun after adding the immediate acknowledgement assertion).
- Two deliberate source faults in a disposable copy are detected by executed
  assertions: dropping settings saves, and dismissing the panel after a failed
  launch. Healthy copied-source runs passed first. These are targeted probes,
  not a comprehensive mutation score; live production source was never mutated.
- All seven daemon/framework Cargo suites pass: **574 primary passes, 11 existing
  ignored entries**, excluding repeated helper subprocess results. This includes
  actual private-bus integration tests. No ignored hardware/desktop checks enabled.
- Daemon/tooling Python suites: **61 passed**. Bar tooling initially lacked Cargo
  in PATH; rerunning in the development environment passes all seven tests.
- Shelllist build-input **18**, profiler **8**, surface-catalog **6**, native search
  **4** and generated-JavaScript contract checks pass. Surface CLI and portal Rust
  tests were not rerun in this pass.
- Nix syntax parses. The new sandboxed derivation/full sibling check was **not
  built**; its runner was executed locally with current-source daemon/search
  binaries. No full Nix, VM, hardware or numerical-coverage acceptance is claimed.

Evidence: `target/test-reduction-vertical/` contains the baseline archive, revisions,
matching inventories/logs, repeated native runs and fault-probe failures. Reproduce
from Shelllist in its development environment:

```sh
cargo build --manifest-path rust/shelllist-search/Cargo.toml --locked --offline \
  --target-dir target/native-search
python3 -B tests/test-native-application.py \
  --app-daemon ../app-daemon/target/debug/app-daemon \
  --search target/native-search/debug/shelllist-search
python3 tests/count-ecosystem-tests.py \
  --rust-logs target/test-reduction-vertical \
  --qml-log target/test-reduction-vertical/qml-final.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
# Add --snapshot target/test-reduction-vertical/baseline.tar.gz and use
# qml-before.log to reproduce the fresh baseline.
```

## Remaining work, not permission for arbitrary deletion

The larger replacement effort is still outstanding: real Clipboard publication
and privacy, NetworkManager SecretAgent delivery/persistence, Bluetooth pairing
and adapter outcomes, and Bar's display/power journeys need their own controlled
native-service fixtures before similarly named local tests can be treated as
redundant. Existing mocked Qt flows are not replacements for native credentials,
authorization, persistence races or hardware adapters. The previous review's
ownership map still applies. No evidence from this single application journey
justifies removing another 323 tests across those independent boundaries.
