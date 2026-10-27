# Clipboard package smoke safety checkpoint — implementation

Scope: W1-CLIP, original producer baseline `55bbbd506a4216d63963461bb06ef19661626ec4`,
frontend baseline `6f14ede26d27cff03b72e51f647ee5e96dba6928`. No inherited seeds.
This is implementation evidence, not completed quality/integration/rollout review.

## Changes and evidence boundaries

Producer `scripts/package-smoke.py` no longer constructs the stale `BUS + "1"`
interface. The synthetic activation probe uses `org.laufan.ClipDaemon2`, checked
against both Rust export declarations. Calls bind to the captured unique owner
on an explicit private address, with auto-start disabled. Loss/replacement never
retries activation or follows the well-known name.

The old real-main/engine/rollback invocation now exits 2 with an explicit NOT RUN
message. `--wiring-only` is an opt-in **static** check, not renamed runtime
acceptance: it checks rendered selected daemon/activation/engine-policy paths,
two units and their existing lifetime/privacy-related relationships without
executing a package binary, systemd-analyze or a manager. Static fixture executables
are inert tripwires. Historical runtime claims are deliberately not repeated.

The replacement runtime boundary is tested only with an inert Gio service. It
uses an allowlisted private HOME/XDG/runtime/helper environment, explicit selected
tools and a generated bus config loading only one synthetic service directory,
no standard/host service directories, includes, systemd activation or helpers.
Commands have output/deadline bounds; spawned groups are cleaned on failure and
success without signaling PIDs discovered through D-Bus. The bus and synthetic
service also have independent lifetime bounds. The fixture imports no producer,
Ringboard or capture backend. See producer `contracts/package-smoke.md` for the
complete contract and reproduction commands.

Tests cover contaminated environment/old recursion marker, mismatched unit and
activation executables, extra services, unresolved engine path, v2 call construction,
failed/slow commands, output cap, failed bus startup, explicit real-main gate,
private activation, wrong v1-only service, failed/name-less activation with no retry,
retired/replaced unique owner, selected owner process identity and cleanup.

## Checks

- Initial isolated construction run: 12 passed, four explicit native skips.
  `check.sh timeout 600 python3 -B -m unittest discover -s clip-daemon/tests -p test_package_smoke.py -v`
  Log: task `artifacts/unit-first.log`. This preceded the added producer-interface
  drift assertion and native lifetime wrapper; it is not the final source pass.
- First synchronous preflight attempt hit the caller's 910s timeout waiting for
  the shared check lock; its empty `artifacts/preflight.log` contains no preflight
  or build result. No failure was hidden or interpreted as acceptance.
- `artifacts/matching-first.log`: bootstrap failed (exit 101), minimal tool PATH
  lacked `cc`; no native probe ran. Reproduced through the frozen framework's
  matching dev shell before producer preflight/capture; no bypass or installation.
- `artifacts/matching-second.log`: matching preflight/capture/syntax and 14
  construction tests passed, native bus startup failed because resolving the
  selected coreutils `timeout` symlink lost its multicall invocation name.
- `artifacts/matching-third.log` and `matching-debug.log`: multicall issue fixed
  with a regression; activation then exposed an over-strict fixture address
  check rejecting dbus-daemon's GUID suffix. Private diagnostics retained; added
  exact-private-path/optional-GUID and forbidden alternate/host address vectors.
- `artifacts/matching-fourth.log`: matching preflight/capture, syntax and **two
  serial full 20-test passes**, zero skips, including all private native cases.
  Diagnostic teardown showed a harmless close-after-bus-exit exception; fixture
  cleanup now accepts an already-closed connection, retaining unrelated failures.
- `artifacts/matching-final.log`, exit 0: matching sibling preflight/capture,
  Python syntax and **two more full 20-test passes**, zero skips, after the final
  cleanup fix. Extra bounded private activation/read/teardown diagnostic passed
  without traceback. A Gio `register_object` deprecation warning remains explicit.

Final bounded command from the family's worktrees:

```sh
/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh timeout 900 \
  env CLIP_SMOKE_DEBUG=1 nix develop ./daemon-framework --no-update-lock-file \
  --command bash "$ORCHESTRATION_TASK_DIR/run-matching.sh"
```

The driver bootstraps the family's local-build launcher in its frozen framework
shell, preflights/captures the producer and enters that matching producer shell;
no installed/stale producer binary is used. Python 3.13.13, D-Bus 1.16.2,
busctl/systemd 260.2 and coreutils 9.11 are explicitly selected and hashed in the
log, along with the source files and snapshot map. Busctl was selected from the
shell's existing PATH, resolved to its immutable store executable and used only
with private addresses, never a live manager/bus. No actual producer/engine binary
identity or packaged-main pass is claimed. Final source SHA256s:

- smoke: `53b482f7b60402946b8bcc4b00ad8690d443d444a2b88a16716c5044e46309ae`
- tests: `60e05e44c2e2ea3ba667f6450faee76ec11ccb1c0e9224b6920bb0c76d67b5e6`
- fixture: `5d2b483416083aba6787e7133be72406786767ba567aed6e6a689ee692ef41be`

Task artifacts are under
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/04-clipboard-package/`.
`run-matching.sh` records exact commands and selected tool/source hashes. No package
main, Ringboard, production capture worker, live bus/compositor, clipboard data,
paste/publication, notification, installation or real service restart is run.
No unit/flake/lock/default/backend changes. Existing retained clients/admission
and all ordinary UI/draft semantics are untouched.

## Open gates / coordinator request

- Real packaged-main/pinned-engine startup, private settings/invalid policy,
  engine negotiation, actual rendered package output, full session readiness,
  upgrade/rollback and selected startup policy remain **not run**. The safe
  exported-service Rust process fixture already accepted by the prior review
  is not the packaged main and is not presented as such here.
- The producer flake's fileset includes `tests` and `test_support` but not `scripts`;
  it runs Rust tests only. Coordinator-owned wiring is required to include the
  smoke script and declare Python/Gio, D-Bus, busctl/coreutils test inputs before
  adding the Python/native check to package qualification. Do not run real main
  automatically as a replacement. No out-of-scope flake change is made here.
- Final serial matched-release measurements require a frozen accepted tuple and
  a separately authorized safe real adapter; this correctness fixture supplies
  no daemon/desktop performance result. Producer contract retains that recipe.
- Python is outside Rust/QML Quality Lens coverage. No Rust/QML/JS/TS/shell/Nix
  source changed. Python syntax/unit/private-native checks are applicable; the
  mandatory exact-session quality review/refactor/test/evidence commit is next,
  not claimed complete in this implementation checkpoint.
