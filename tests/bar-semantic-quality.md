# CQ-10 / CQ-13 quality continuation

Original implementation status stays **partial**. The upstream battery acquisition
validity row in [bar-semantic-facts.md](bar-semantic-facts.md) is not implemented by
this refactor. Bridge stays default; no integration/rollout approval.

## Full baseline inventory and pinned evidence

Shelllist `6f14ede26d27cff03b72e51f647ee5e96dba6928` → implementation
`112e2b813372dd35f35f5ea7eab221c78e62bb1e`: two QML files, four generated JS files,
three TS sources, API/nested JSON companions and scoped evidence. Paired producer
baseline/implementation is `83658f4` → `f5b5b97`; seven Rust sources including tests
and fixture producer, JSON and contract. No seeds or generator source changes.

Every changed QML/JS file is included in the task-local static config, including
`BarProtocol.generated.js`. TS and native/JSON companions are fingerprinted, not
pretended to be JS/Rust analysis. Actual TS strict compilation and generated parity
are separate. No repo config, threshold, exclusion, suppression or external-type
allowlist changes. Unsafe project runtime/profiling/coverage adapters were not used.

Pinned QML Lens `97feb1f714c680ffcceedc935ecaa974d0c52cb1`; aggregate dist JS digest
`b6443d1f0b8a610f73c79926080245e718f53ebaa0d903639bfb44df497b2a85`.
The CLI file's own SHA-256 is
`03cd63e3ca16f990e340f2eabee396e8bbfbf8a1606acdd172f20f4b8ba831e5`;
these are different hash scopes, not substituted binaries. Rust uses pinned
RQLens `d28f3d9` and its unchanged helper manifest; normal locked helper compilation
in the task's private cache is disclosed in producer quality evidence.

All configs, inventories, raw artifacts, triage, drivers and logs live under
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/05-bar-semantic-facts/quality/`:
`before/{rust,qml}`, `after/{rust,qml}` and clean-quality-head `final/{rust,qml}`.
The shelllist lens runs static quality/complexity/clones/cohesion/binding/semantic/
health/catalog producers only; catalog does not claim execution.

## Findings, refactors and retained uncertainty

- QML/JS: six files, 88 functions, two QML components, no parser diagnostics.
  BEFORE has 19 findings; AFTER 18. The removed finding is the new `powerEvent`
  test helper's incomplete signature: add `profile: var`, `revision: int` and
  `: void`. It changes no transaction, route, captured value or assertion.
- Before/after both have seven unresolved imports, three unresolved types,
  36 skipped semantic evaluations across 18 rule families, and partial clone
  analysis (zero emitted groups but 56 omitted windows). These are not full
  semantic or duplicate-free passes. Actual Qt complements, not overrides them.
- Retain three cohesive native-state/OSD/actual-command test journeys despite
  length hints. The stale/unknown/disabled/captured-once/explicit-retry risks are
  assigned acceptance, not incidental request-count tests. Do not split journeys
  mechanically or delete distinct protections to reduce metrics.
- Retain existing BarController size/action-routing/property surface and unrelated
  notification helper complexity. No media/clock/network-kind/notification
  conversion or broad controller rewrite is part of this review.
- Paired Rust refactor shares the ordered native supported-profile list across
  projection and both validation boundaries. It preserves the public preflight
  and owner revalidation before pause persistence/hold release. No QML policy
  inference, fallback target, implicit retry, threshold or admission change.
- Rust counts remain 91 hotspot records, four clone groups/61 duplicated lines,
  78 reliability advisories and 48 partial type-health records. Seven changed-hunk
  unwrap sites are test-only setup/fake mutex checks. Existing clone/test advisories
  remain with distinct-risk rationale. Authored syntax, unexpanded derives/cfg,
  auto-discovered Wayland macros, narrow module attribution and disabled semantic
  identity are explicit limits; no compiler-complete ownership claim.

## Reproduction and affected checks

From the task's `worktrees/`, using
`CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh`:

```sh
$CHECK timeout 1800 nix develop ./daemon-framework --no-update-lock-file \
  --command bash ../quality/run-analyzer.sh before
$CHECK timeout 1800 nix develop ./daemon-framework --no-update-lock-file \
  --command bash ../quality/check-refactor.sh
$CHECK timeout 1800 nix develop ./daemon-framework --no-update-lock-file \
  --command bash ../quality/run-analyzer.sh final
```

Phase directories are write-once; use a fresh owned task artifact destination for
an explicitly authorized new run, not overwrite existing evidence. Second command
includes AFTER production and affected checks, all passed (`logs/refactor.log`):
226 ordinary Rust library + 29 update-worker + one ordinary native integration;
strict all-target/all-feature Clippy, fmt/build; producer API/read/control/battery/
display/notification and generated-protocol parity; strict TS generated-JS parity
and `tsc --project tsconfig.json`; generated contract negatives/offline bar parity;
QML lint, surfaces/build inputs; **460 Qt passes / zero failures / one existing
renderer skip**; private Quickshell socket shared-read/publication/renewal/peer probe.
Matched sibling-source Nix bar contract has 231 release library + 30 update-worker
+ two native integrations; Nix Qt also has 460 passes / one existing skip;
Nix buildInputs passes. Native/Qt tests are complementary, not hardware journeys.

Same pinned configs/tool sources and the shared private check lock throughout;
no source overrides, host effects, deployment, installation/profile change or final
benchmark. Private HOME/XDG, unavailable buses/compositor, offscreen/software Qt,
fake point-to-point power service and no-activation native bus remain enforced.
The existing synthetic watcher-registration timing smoke is not final latency or
memory qualification. See implementation evidence for the queued exclusive serial
matched-release recipe and remaining performance/startup gates.

Quality status is **partial** with reviewable BEFORE/AFTER evidence, a justified
contract-drift refactor and the corrected signature; not a global quality pass.
CQ-10 acquisition validity, static uncertainty, original failed attempts and the
unrelated brightness temporary-script ETXTBSY observation remain retained.
