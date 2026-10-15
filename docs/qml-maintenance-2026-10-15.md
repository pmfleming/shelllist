# Focused Lens maintenance review

Baseline: clean `e296b2b`. Local Lens 0.5.0 from `../qmlqualitylens`, Qt 6.11.1.
Evidence: ignored `target/lens-maintenance-current/{before,after}/`.

## Review and refactor

- `wifi/WifiRequestMetadata.js` was the highest cognitive-complexity production
  function. Replace nested mutation with fresh read/effect records, early returns
  for parameter-dependent cases and explicit method descriptors. Response route,
  execution and conflict overrides now live together. Unknown/inherited names
  remain conservative effects; refresh requires literal `true`. No parameters,
  secrets or QR payloads enter the records.
- `DaemonBackend.classifyRequest` is now a typed overridable method rather than
  a nullable callback property. Wi-Fi overrides it; other backends keep the empty
  classification. Transport ownership, metadata retirement and reentrant-ID
  protection are unchanged. Remove the unreachable `qr-connect` response-table
  entry: both connection variants are classified as `connect-start`.
- `ActionDetailsPane` owns the existing scaled content/footer size once, replacing
  six panel-local calculations and redundant aliases. Battery's two already-wrapping
  headings reuse `SectionLabel` with the same role and layout constraints.
- Applications uses one asynchronous loader for its mutually exclusive pages,
  rather than three parallel loaders. Explicit component selection fails closed
  for unknown tabs. Update Lens dynamic edges for all three pages. Shared field
  navigation still discards unsaved edits on page replacement; submitted work
  and acknowledgement stay with the controller.

## Measurements

Both revisions use identical source roots, thresholds and tools-disabled static
configuration, including the clarified dynamic edges. The baseline is a Git
archive, preserving the Battery module symlink. No production analysis exclusions,
quality suppressions or test skips were added. The following production scope is
configured discovery minus `tests/`, `dev/` and `*.generated.*`; generated code and
canonical TypeScript are not silently folded into these function measurements.

| Metric | Before | After |
| --- | ---: | ---: |
| Production function cyclomatic sum | 8,000 | 7,998 |
| Production function cognitive sum | 5,522 | 5,478 |
| Production function weighted effort sum | 35,699 | 35,592 |
| Production component weighted effort sum | 46,056 | 46,038 |
| Mean component locality | 75.619 | 75.672 |
| Mean component leverage | 37.922 | 38.016 |
| Production source lines | 35,901 | 35,865 |
| Tracked physical code lines, including regressions | 66,718 | 66,713 |
| Production lines covered by expanded normalized clones | 1,319 | 1,277 |
| Expanded normalized clone groups, whole configured scope | 180 | 180 |
| Structural QML clone groups | 40 | 40 |

`classify` cyclomatic/cognitive/weighted effort falls **15/56/168 → 11/13/54**;
its maximum nesting falls **8 → 2**. These are advisory weighted effort metrics,
not developer hours. Baseline Halstead is incomplete for the nested function, so
there is no defensible before/after Halstead-effort comparison.

The ordinary clone scan remains capped at 100 groups. The separate expanded scan
uses the same Lens detector with limits 500,000 keys / 1,000 windows per key /
10,000 groups; both runs omit zero windows/groups. Clone-covered lines are the
union of production instance line ranges across its groups, not a group-length
sum. Duplicated footprint falls, **group counts do not**. Overall score stays 83;
parser diagnostics stay zero. Physical code counts use tracked QML/JS/TS/Rust/
Python/shell/Nix files, excluding prose/configuration and counting symlinks once.

## Validation and remaining work

- Full native Qt: **472 passed, 0 failed, 1 existing software-renderer skip**;
  baseline **464/0/1**, including lifecycle hooks. Eight added behaviors cover
  classification variants, independent snapshots and actual Ctrl+Tab page
  replacement/discard. Existing field, domain, failure and acknowledgement suites
  remain enabled.
- Strict QML lint, offscreen runtime smoke, daemon-boundary JavaScript and
  source-tree relative-import checks pass. UI drift review reports zero prompts;
  `git diff --check` passes.
- A local differential check compared 3,672 old/new classification outputs,
  including inherited names, profile variants and non-boolean refresh values:
  identical. This supplements, not replaces, native tests.
- Run Qt with `QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh`; the initial run
  without fixture-file access failed 92 reads. Enabling the existing fixture
  prerequisite gives the clean baseline above; no assertion was weakened.

Lens audit remains **incomplete** on unresolved binding-side-effect evidence.
Execution tools are disabled only in the local measurement configs; lint, Qt and
smoke were run separately. No coverage/profiler, full sibling-aware Nix release
build, live compositor, hardware, IME or human accessibility acceptance is claimed.

Remaining review candidates include notification acknowledgement and Wi-Fi secret
handling hotspots. Their domain guards need focused evidence before further
refactoring. Generated protocol-validator clones belong to the generator/build
boundary, not hand edits to generated outputs. The enum-only tray mock's uncertain
export reachability is not sufficient evidence to delete it.
