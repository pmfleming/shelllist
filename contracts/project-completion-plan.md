# Project completion plan — worker delivery and coordinator integration

Authorized 2026-10-26: plan and begin implementation of the remaining project,
with each code worker delivering **changes → tests → implementation commit →
quality check/refactor → affected tests → quality commit → coordinator integration**.
This authorizes repository work, not deployment, live effects or a default switch.

## Baseline and completion definition

Start from reviewed Shelllist `be9550e` / audit `74d882f`, NM `7f2952e`, clipboard
`55bbbd5`, bar `83658f4`, application `0e6de17`, BT `3e0ecb4`, framework `563e7f9`,
update `7c3432f`. The first run freezes the additional planning commit too.
Do not redo completed adapters or treat old worker commits as approved integration.
[Review record](../tests/worker-integration-review.md), [stream matrix](unix-jsonl-stream-matrix.md),
[conversion tickets](rust-qml-conversion-audit.md) and
[startup design](socket-startup-design.md) define scope and evidence limits.

Current progress is recorded in the [first Wave 1 review](../tests/wave-one-integration-review.md)
and [remaining-branch integration review](../tests/remaining-work-integration-review.md).
All delivered checkpoints are now integrated in their reviewed bounded scopes,
including the focused Bluetooth authority/draft repair, `wifi.status`, clipboard
private smoke/CI safety and bar semantic presentation/manual profile targets.
Connectivity/inventory and other unfinished NM streams, CQ-10 acquisition validity,
broader BT lifecycle and real packaged-main/rollback acceptance remain open.
Historical missing-extraction blockers are not substitutes for fresh evidence;
partial implementation/analysis and integration do not close the project.

The [refreshed Wave 2 assignments](completion-wave-two.md) start six bounded
parallel checkpoints from the integrated family, including the later delayed-paste
handoff fix. The user's separate live-session socket opt-in does not change package
defaults or authorize workers to affect that session. Startup-policy selection and
private qualification gates remain explicit; later tasks use refreshed dependencies.

There are three distinct exits:

1. **Implementation complete:** all required recovery and selected semantic/schema
   conversions below are integrated, matching negative-path/Qt/native gates pass,
   and every audit ticket is implemented, explicitly retained or resolved by an
   evidenced owner decision. No quiet abandonment of U/unknown items.
2. **Qualification complete:** packaged startup/readiness, mismatch/upgrade/rollback,
   remaining native payload/crash cases and stable serial load/release measurements
   meet recorded criteria. Correctness tests are not performance measurements.
3. **Rollout approved:** separate explicit decision by the user. Until then bridge
   remains default and socket flags remain independent opt-ins. Completing the first
   two exits does not authorize deployment or removal of D-Bus/retained clients.

## Worker lifecycle and integration gate

- Every delegated session uses **openai-codex/gpt-6.1-sol, high**, verified from
  environment and actual assistant events. No fallback or recursive agents.
- At most six active sessions across implementation and quality. Each worker has
  its own frozen eight-repository family, owned branches and narrow path allowlists.
  Worktrees are contractual isolation, not an OS sandbox.
- Implementation checkpoint: inspect actual sources/contracts, add negative-path
  coverage, implement, run private checks, commit scoped files, record immutable
  handoff and unfinished acceptance. Existing seeded BT/framework work is inherited
  input, not a waiver of fresh verification or quality review.
- Quality checkpoint resumes that **exact exited session** only after its process
  group is gone. Inventory the complete baseline-to-implementation diff including
  seeds/tests/tools; save BEFORE evidence, triage, refactor only justified findings,
  save comparable AFTER evidence and rerun affected checks. Commit the refactor and
  tracked quality evidence. If no code refactor is justified, commit the evidence
  and rationale rather than manufacturing code churn or an empty commit.
- Rust changes require Rust Quality Lens; QML/JS changes require QML Quality Lens;
  mixed changes require both. TypeScript/Python/shell/Nix require their own existing
  checks and explicit unsupported-by-lens disclosure. Docs-only is N/A. Missing
  extraction is blocked; partial analysis is not a complete pass.
- Pinned analyzer-managed **locked extraction-helper compilation into private
  caches is explicitly allowed**. Tool source/CLI/version/lock modifications,
  installations and unrestricted runtime/coverage campaigns are not. Read tool
  configs before use. This resolves the previous BT/framework helper ambiguity.
- All heavy checks use one shared private check lock; no competing performance
  runs. Preserve source/binary/config hashes, exact commands, failures and skips.
  No host buses/compositor, real credentials, clipboard, applications or hardware.
- Coordinator reviews code, scope, quality artifacts and acceptance—not just exit
  status—then integrates compatible producer/frontend commits, resolves shared
  generated fixtures, reruns combined Rust/Qt/contracts/Nix/native gates, commits
  integration evidence, and records a separate coordinator disposition.
- No shell script automatically cherry-picks a handoff into main. Background
  supervisors collect/validate handoffs; semantic integration is coordinator work.
  Subsequent waves are prepared from newly integrated heads, not stale snapshots.
  A stopped/partial checkpoint needs an explicit continuation; never implicit replay.

## Wave 1 — launch six independent owners

| ID / owner | Implementation checkpoint | Acceptance and boundary |
| --- | --- | --- |
| W1-BT / Bluetooth | Rebase inherited device-operation recovery (`54532b2`, frontend `63e1d0b` + `1bcdca7`) into the frozen family; finish coordinator-owned global BT fixture parity and repair demonstrated integration defects. Do not mix pairing/scan/OBEX expansion into this checkpoint. | Fresh producer/actual Qt/native quiet-loss, owner/cancellation/admission checks; all BT fixtures/bindings and matching contracts. Required Rust and QML BEFORE/AFTER review, unlike the blocked prior handoff. |
| W1-NM / Networking | Implement atomic full-status/connectivity/inventory read/watch ordering and quiet-loss/stale-read recovery, retaining the existing collection and owned-connect paths. Close a coherent subset if a shared protocol dependency blocks the rest; identify each remaining row. | Real producer serializers, old/malformed/reordered/quiet records, invalidation racing reads, retained prompts/connect work and healthy peers; actual Qt plus private native evidence. Never reconnect or submit secrets as recovery. |
| W1-FW / Framework qualification | Rebase inherited harness `4238b1b`, complete its missing Rust analysis/refactor, validate bounded harness self-tests and a usable producer-adapter contract/recipe. | Private fake services, real framing/admission, provenance and unavailable metrics. No final benchmark or production transport rewrite. |
| W1-CLIP / Clipboard packaging | Fix stale package-smoke interface and harden the smoke's private activation/environment boundary with executable regression tests. | Synthetic/private service fixtures; reject host activation/service directories and unintended effects. Distinguish smoke-script correctness from packaged-main/session acceptance. No startup strategy or live capture selected. |
| W1-BAR / Bar semantic facts | CQ-10 unknown/unit telemetry and CQ-13 eligible next manual power-profile target; producer facts consumed by UI, no guessed domain fallback. | Producer unavailable/zero/nonfinite and eligibility vectors; generated companions; actual Qt disabled/unknown/one-command/stale-target behavior; retain battery/power safety and UI geometry. |
| W1-APP / Application frontend acceptance | CQ-15 canonical submitted Close action classification; extend private real Quickshell coverage to near-limit app responses using the existing safe fixture. | Close/CloseWindow identity and uncertain outcomes, no optimistic dismissal/replay; actual Qt; bounded native large-record routing/healthy-peer recovery, no user launches or catalog/window access. |

Only these six are initially queued. No concurrent worker edits the same producer
family's domain implementation in this wave. Shared Io/Core, schemas/generators,
service units, flakes/locks and global stream documents remain coordinator-owned
unless a later assignment explicitly transfers a named file. Cross-owner requests
must include a failing vector/proposed contract, not a private policy fork.

## Wave 2 — refresh baselines after relevant Wave 1 integration

| ID / owner | Work | Prerequisites |
| --- | --- | --- |
| W2-BT / Bluetooth lifecycle | CQ-01 pairing observation vs response authority, expiry, scan lease/status cleanup, ordered owner-private request recovery and aggregate boundaries. Split pairing/scan into reviewed checkpoints as necessary. | W1-BT integrated; owned status API and global fixture parity verified. |
| W2-NM / Networking prompts/outcomes | CQ-04/CQ-05 private prompt lifecycle and complete native field descriptors/submitted-form normalization; then scan/band/hotspot/VPN terminal outcomes and statistics discontinuities/health filtering. Separate bounded checkpoints; do not declare all rows complete from one operation. | W1-NM accepted clocks; existing connect guards and eligible secret observers retained. |
| W2-SCHEMA / Shared boundary | Add only demonstrated missing generated result/schema enforcement, with Rust/JS Unicode, cross-field, null/optional/discriminator parity and negative vectors. No unconditional trust or universal enforcement of incomplete schemas. | Coordinator approves explicit generator/Io ownership and domain contract request. |
| W2-UPDATES / Bar updates | CQ-06 producer-owned update wire schemas/result enforcement; CQ-07 native update semantic facts. Preserve UpdateController as read/copy/navigation transactions, not an update executor. | W1-BAR integrated; W2-SCHEMA contract available before dependent consumer wiring. Sole bar producer writer in this wave. |
| W2-ACCEPT / Native acceptance | Remaining BT/NM framing/retained bridge/D-Bus cases, real producer-process restart and consumer-generation paths; explicit pre-ack/accepted/terminal uncertainty. | Relevant recovery owners integrated. Assign per producer; never overlap that producer's lifecycle worker. |
| W2-START / Startup readiness | Implement chosen strategy, compatible-endpoint/generation-or-unique-owner fences, per-consumer observation readiness, bounded queues/deadlines and cleanup exceptions. | Startup decision below, stable producer compatibility facts, explicit shared Io/framework/service ownership. No parallel edits with W2-SCHEMA. |

W2-NM and W2-BT are ordered lanes, not permission for one unbounded rewrite.
Every sub-checkpoint follows the same two-commit/quality/integration lifecycle.
Any unfinished Wave 1 scope stays explicitly open and precedes dependent work.

## Wave 3 — remaining semantic and cross-domain ownership

- **W3-BT:** CQ-02 native rescan recommendation vs local browsing intent; CQ-03
  native ranking/list/disambiguation/effective-policy facts. After BT lifecycle
  recovery, with existing native search and explicit user intent preserved.
- **W3-MEDIA:** CQ-08 media action/identity facts; CQ-09 controlled-clock evidence
  and an explicit sampling/freshness/interpolation decision before moving timing.
  Keep assets/pixels/visual interpolation in QML; never present unknown as zero.
- **W3-CLOCK:** CQ-11 native minute-boundary clock/date/timezone facts, after media
  work is integrated. No host-timezone fallback or per-consumer producer.
- **W3-NETWORK-KIND:** CQ-12 NM-owned link/strength/unknown facts and bar consumption,
  after NM status/prompt and bar semantic work. One explicitly paired NM/bar/UI
  owner; active Wi-Fi with no AP is not proof of Ethernet.
- **CQ-14 is retained:** Core/Model stays UI-owned. Optional strict-boundary hardening
  requires an actual failing vector and its own assignment, not a mandatory port.
- **W3-CRASH/PAYLOAD:** finish remaining app/bar/clipboard combined native frontend
  and producer-process scenarios, packaged-main boundaries and effect-receipt loss;
  retain scoped tests already integrated rather than repeat them as new coverage.
- **OPS-STATUS:** project tooling follow-up: show coordinator dispositions separately
  from original worker/quality status in the read-only dashboard. Preserve raw
  partial/blocked evidence; do not paint every terminal task green. `/etc/nixos`
  is a separate configuration repository: establish/review its fresh baseline
  before assigning an isolated tooling worker. Not a daemon rollout prerequisite.

Bar work is deliberately serialized across W1-BAR → W2-UPDATES → W3-MEDIA →
W3-CLOCK → W3-NETWORK-KIND to avoid competing model/protocol/presentation owners.
Other independent families may occupy the remaining slots.

## Wave 4 — stable integration and release qualification

1. Freeze accepted source tuples; all ordinary Rust, strict lint/formatting, generated
   producer/consumer parity, actual Qt, surface/build-input and sibling Nix gates.
   Invoke ignored private native cases explicitly; do not blanket-run live/systemd
   cases. Resolve quality limitations/findings by explicit review, never suppression.
2. Adopt the shared harness through real producer-owned private adapters. Run many
   owners/consumers, sustained mixed reads/subscriptions/renewals/cancel/status,
   bursts/overflow, single/multi-worker stalled peers and bounded memory. Verify
   no replay, retained admission and healthy-owner progress.
3. Reserve an exclusive serial measurement window with no other workers/builds.
   Match release sources, binary hashes, fixture inputs, warmup/sample counts and
   full process-tree scope (including retained bridge children). Record p50/p99,
   RSS/PSS/private memory and unavailable metrics. No inferred whole-desktop savings.
4. Validate packaged cold start, producer/frontend mismatch, owner replacement,
   shutdown, upgrades and rollback against private effective service/environment
   graphs. Keep unavailable/loading baselines legitimate, cleanup bounded and
   retired-owner authority unrecoverable. Correct clipboard smoke before reliance.
5. Coordinator writes a release-readiness matrix with all required rows closed or
   explicitly excluded by the user—not a percentage or an aggregate test score.
   Request separate rollout/live-environment approval. Bridge stays default meanwhile.

## Explicit decisions and blocked gates

- **Startup deployment strategy:** choose independently configured eager services,
  explicit activation or socket activation, plus per-daemon exceptions, session
  composition/environment owner and bounded startup budget. Reviewed recommendation
  is eager services for a first isolated qualification candidate, **not selected**.
  Readiness/compatibility requirements apply regardless. This plan does not silently
  approve session-target ordering, force app residency or remove non-systemd support.
- Media timing and network-kind scope require the recorded controlled evidence and
  domain-owner decisions before conversion, not guessed defaults.
- No live desktop/hardware measurement, deployment, service restart, real cache
  deletion, push or default switch is authorized by this implementation plan.

## Run and evidence

First implementation/quality queue:
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z`.
`tasks.json` and `manifest.json` provide precise paths, seeds and frozen identities;
`worker-instructions.md` and `quality-instructions.md` enforce the two-stage workflow.
Each phase has a 90-minute checkpoint deadline and bounded logs. These are checkpoint
limits, not estimates that the entire project fits in one run.

Coordinator integration and newly authorized successor waves are separate recorded
steps. A background supervisor cannot supply semantic review or launch dependency
waves merely because a worker exits successfully.
