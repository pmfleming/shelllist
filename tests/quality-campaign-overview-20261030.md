# Shelllist ecosystem quality campaign — 2026-10-30

Eight GPT-6.1 Sol workers, each using high reasoning effort, completed one initial
quality stage and five ranked follow-up improvements. Each stage has its own
commit: 48 implementation/evidence commits across eight repositories. The parent
reviewed the production diffs and recorded test evidence from every worker.

Before launching workers, the parent committed the user's existing changes:
Shelllist `62f31cb` (app Turso dependency exceptions) and bar-daemon `bd369b4`
(explicit agenda ownership release). Those are outside the 48 campaign commits.
No pushes, deployments, production service restarts or live settings changes were
performed. Dependency versions, protocol fixtures and quality policies were not
changed by the campaign.

## Evaluated revisions and evidence

| Repository | Clean baseline | Six-stage final revision | Detailed evidence |
| --- | --- | --- | --- |
| shelllist | `62f31cbb89e5865acaf2b1ef6fb0ec05e85d25ca` | `f28f3463d6a64af80fa540f3703d70825dff0ad5` | [Shelllist](quality-campaign-20261030.md) |
| daemon-framework | `aeb58d3d9044342b1b3b52c5a60fd51188c8d0d8` | `b0c78d48a97065df5c3b4958894fd0748b6ef364` | [Framework](../../daemon-framework/tests/quality-campaign-2026-10-30.md) |
| app-daemon | `0ebd148a0341b6acef7675c0ac6e9ab00a232d75` | `a949e36afece52574e4da4cf07c42e152fa36781` | [Applications](../../app-daemon/quality/campaign-2026-10-30.md) |
| bar-daemon | `bd369b4873026abe84d9d8157655d2bdc2db064d` | `d520cb89071fc9754432a41d7faf9fa8d1adec64` | [Bar](../../bar-daemon/tests/quality-campaign-2026-10-30.md) |
| bt-daemon | `8fe2f64d8528b66289548af0c1ea5238d9247195` | `72104ab4e924df0f7ffd5184458954d776c0e1be` | [Bluetooth](../../bt-daemon/tests/quality-campaign-2026-10-30.md) |
| clip-daemon | `8c2358af544b5f9d6df7a5c18c1ccc690a662b0e` | `466e7862ae20a4680b5962fcfa267d6359bc0f7d` | [Clipboard](../../clip-daemon/tests/quality-2026-10-30.md) |
| nm-daemon | `4b84f64be1f7cfdd8c7b0a32b5bb2c5716600f45` | `3ae34a0e1479bb3916b822ea9ad1b2dedc12b18e` | [NetworkManager](../../nm-daemon/tests/quality-campaign-2026-10-30.md) |
| update-daemon | `7c3432f22ea82ebcd941f6ce8bcd562e2724d130` | `3d3016dd7724f129a4c7b195576d924e970df7ee` | [Updates](../../update-daemon/tests/quality-campaign.md) |

All eight trees were clean when the parent started final integration validation.
This overview is an additional evidence-only Shelllist commit; it does not change
the tested implementation revisions above.

## Outcomes against the requested objectives

The six-stage implementation plan is complete. The full set of requested metric
outcomes is **not achieved**. Correctness and allocation/ownership improvements
are supported by source review and native behavior tests, but do not imply that
every static quality metric improved.

- Cognitive/cyclomatic complexity and effort: several targeted owners improve;
  app-daemon's aggregate measures worsen. Some other repositories trade one
  measure against another. See each report for complete scopes and denominators.
- Leverage/locality: concrete policy reuse and ownership improvements exist,
  but locality sometimes decreases. Several baseline/final semantic graphs are
  incomparable because resolution timed out or remained incomplete.
- Dead code/cloning/escape hatches: verified private bypasses, redundant copies,
  repeated parsing and duplicate definitions were removed. This is not proof of
  whole-program dead-code elimination. Aggregate duplication is mixed.
- Coverage with less test volume: existing test owners gained boundary/race
  cases, but test LOC increases in seven repositories. Several coverage reports
  include inline test code; four projects lack usable paired coverage. Raw test
  counts and added assertions are not numeric code coverage.

## Comparable code-volume results within each repository

These are each worker's fixed baseline/final physical code inventories, not one
uniform cross-repository census. Shelllist and update-daemon include multiple
code languages; other rows count Rust. Clipboard excludes vendor code and
includes examples/tools. Do not sum these as a standardized ecosystem metric.
Reports, lockfiles and other non-code evidence are outside these inventories.

| Repository | Before | After | Change |
| --- | ---: | ---: | ---: |
| shelllist | 80,068 | 80,066 | -2 |
| daemon-framework | 11,336 | 11,468 | +132 |
| app-daemon | 17,741 | 17,836 | +95 |
| bar-daemon | 54,818 | 54,815 | -3 |
| bt-daemon | 21,773 | 21,819 | +46 |
| clip-daemon | 18,167 | 18,195 | +28 |
| nm-daemon | 41,378 | 41,641 | +263 |
| update-daemon | 12,636 | 12,633 | -3 |

## Verified worker results and limits

The parent inspected the recorded commands/results and production changes; it
did not independently rerun every worker suite. Subprocess results and repeated
runs are not added to parent-suite counts.

| Repository | Executed evidence | Remaining qualification limits |
| --- | --- | --- |
| shelllist | 701 Qt checks passed, one existing RHI skip; strict lint, TypeScript and generated contracts pass | Numeric coverage unavailable; original worker package check blocked by then-untracked sibling files |
| daemon-framework | 73 Rust tests passed, one profile ignored; strict Clippy and all three Nix checks pass | LOC/duplication goals unmet; coverage includes tests; semantic inventory partial |
| app-daemon | 70 Rust and three Python tests passed; nine Rust tests ignored; strict Clippy passes | Metric gate fails against older incompatible baseline and unreviewed budgets; campaign-local complexity/size increases; no numeric coverage |
| bar-daemon | All 333 Rust cases executed, four Python tests and standalone Turso contract pass | Strict audit/deny policy fails; partial macro/catalog evidence; coverage essentially flat |
| bt-daemon | 85 Rust tests and two Python tests pass; two probes ignored; strict Clippy and coverage threshold pass | Strict quality/API evidence and dependency audit fail; hardware/probes unqualified |
| clip-daemon | All 111 cases exercised across regular/large/native runs; Turso and private desktop acceptance pass | No baseline coverage gain established; total/test LOC and duplication increase |
| nm-daemon | 112 Rust and eight Python tests pass; four Rust tests ignored; all 21 Nix checks pass | Earlier private SecretAgent timeout has unresolved cause; later full runs pass; no paired coverage gain |
| update-daemon | 100 Rust and 28 Python tests pass; one Rust test ignored; six executed verifier gates pass | Coverage filters one environment test that passes normally; unchanged uncovered-line count; packaging/live acceptance unqualified |

Explicit policy failures are retained, not waived:

- Bluetooth audit flags `crypto-bigint 0.5.5`, `RUSTSEC-2026-0387`.
- Bar audit flags nine advisories across quinn-proto, rustls, rustls-webpki and
  webpki-roots; cargo-deny additionally reports policy failures. Exact versions,
  IDs and diagnostics are in its linked report.
- App's tracked metric baseline/policy remains unchanged and failing.
- Partial macro/semantic/catalog evidence and optional-check skips never count
  as passing quality certification.

Evaluator limitations also matter: Applications and Bluetooth could not run the
newly built lens because dependency metadata exceeded the operating system's
per-argument/environment-string size limit. They used retained evaluator binaries
for their paired measurements. Clipboard and Bar also froze existing binaries.
Binary/config identities are recorded in each report; not every retained binary
has independently established source provenance. Metrics are compared only within
each project's matched evaluator, never as a uniform cross-project score.

Dependency upgrades and broad gate-policy repairs were not included in the
workers' version-preserving refactor scope. This scope was chosen by the parent;
it is not a user prohibition on future fixes.

## Final integration validation

Parent command, using Shelllist's cached Nix development environment:

```sh
source .direnv/flake-profile-*.rc
CARGO_BUILD_JOBS=2 ../daemon-framework/tools/local-build check . \
  --keep-going --print-build-logs --max-jobs 2 --cores 2
```

This captures all current sibling sources through the approved local-build path.
It includes producer/consumer contract checks and the packaged Qt suite, whose
fixtures are generated by the newly built producers. It changes no installed
service. Log: `target/quality-integration-20261030/final-local-build.log`.

The parent byte-compared all 108 added/modified campaign files in this captured
graph with the eight committed revisions. Every comparison matched. Paths,
revisions and SHA-256 file identities are retained in ignored
`target/quality-integration-20261030/captured-change-identities.json`.

Result: **all 28 flake checks passed**, command exit 0. The packaged Qt suite
executed **701 checks, zero failures, one existing skip** (173.145 seconds).
The update-worker release package executed **100 Rust tests, one ignored**.
Producer/frontend registries, generated reply/request contracts, current protocol
bindings, shared build inputs, packaged imports and the native application journey
passed. Valid cached checks were accepted by Nix; not every derivation rebuilt.
The earlier Shelllist package blocker is resolved, and update-worker now has
package validation in addition to its worker-local evidence.

The update-worker fixup log includes `patchelf: open: Text file busy`; Nix still
completed the package and exited successfully. This warning is retained in the
raw log, not silently presented as a warning-free build. Strict dependency audits
and quality policies listed above remain failing; the 28 integration checks do
not replace those separate gates or establish hardware/live-login acceptance.
