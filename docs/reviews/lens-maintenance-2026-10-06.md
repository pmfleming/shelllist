# Bounded QML maintenance — 2026-10-06

## Scope and comparison

Baseline: Shelllist `80056cc276a068fc9adcf71f34de568a0413de4d`.
Analyzer: local `../qmlqualitylens`, v0.5.0,
`c7e4d0bc7504ba11317927e87c2007a15616ad37`.
No thresholds, suppressions, entrypoints or production configuration changed.
Configuration SHA256:
`3d4158632ffd5152b95fe17566b82f648db4f01934a3c9fc89b7599922828f54`.

Concurrent media icon/artwork changes appeared during this review. They were
left untouched and copied into the frozen baseline for a **matched** comparison:
`README.md`, `bar/{MediaChip,SystemChooserContent}.qml`, `bar/SystemEntries.js`,
`tests/qml/imports/Quickshell/Quickshell.qml`, and
`tests/qml/tst_{bar_material,system_choosers}.qml`. Their code and tests are present
on both sides, not claimed as maintenance work. Their patch and hashes are saved
with the evidence.

Static comparisons disable external tools on both sides, separate production
from tests, and raise clone enumeration limits equally to 200,000 keys,
1,000 windows/key and 10,000 groups. Both scopes have complete clone enumeration:
no omitted groups/windows. The ordinary full-tool run retains project defaults;
its bounded clone report is not substituted for these measurements.

## Changes and ownership

- Remove unused `NotificationQuickActions` and its module export; current
  notification commands already use `NotificationCommands`. Remove the unused
  `SurfaceActionRow.actionLine` ID and `ActionToolbar` delegate index.
- Remove obsolete rectangular action-width metadata from four providers and
  `Core.Model` normalization. Circular geometry belongs to shared controls;
  action roles, grouping, confirmations, capability and in-flight guards stay.
- Replace callback-valued `var` properties with typed `replyRequested` and
  `removalFinished` signals. Toast/history owners still control reply submission,
  dismissal, acknowledgement and removal. Update the manual form fixture too.
- Share only retry/discard **presentation** in `Ui.RecoveryActions` across
  Clipboard, Bluetooth adapter settings and device renaming. Keep passive labels,
  control identities, access keys and independent enabled guards. The domain
  owners retain their different drafts, retries, lease handling and discard
  effects. No common recovery controller or callback dispatcher was introduced.
- Share `DetailsNavigation.fieldBoundary` between field discovery and loader
  readiness, rather than maintaining two exclusion lists. Composite editable
  controls remain single stops; commands/modals/information-only content do not
  become fields.
- Flatten notification history-response handling and Activity event dispatch.
  Preserve revision checks, resident-store ownership and late-response behavior.
- Flatten first-invalid-address/first-overflowing-octet lookup in IP diagnostics.
  Change the canonical TypeScript and matching generated JavaScript, retaining
  validation precedence, one-based indexes and all native input bounds.
- Type display focus tabs and Bluetooth completed-request IDs as `list<string>`.

This is deliberately bounded maintenance, not a rewrite of daemon or chooser
state machines. High-effort notification history, chooser-session restoration,
display policy and validation remain review hotspots. Their asynchronous safety
and domain distinctions are not duplication to erase merely for a score.

## Measured results

Lower is better except locality/leverage. Effort and scores are Lens heuristics,
not estimates of engineering time. These are small improvements, not a claim of
large architectural simplification.

| Metric | Production before → after | All analyzed sources before → after |
| --- | ---: | ---: |
| Source lines | 37,639 → 37,578 | 45,512 → 45,498 |
| Physical lines | 42,065 → 42,002 | 50,193 → 50,177 |
| Components | 293 → 293 | 342 → 342 |
| Cyclomatic complexity sum | 7,339 → 7,332 | 7,940 → 7,938 |
| Cognitive complexity sum | 4,943 → 4,917 | 5,190 → 5,164 |
| Function effort sum | 36,911 → 36,847 | 42,358 → 42,319 |
| Component effort sum | 41,537 → 41,458 | 50,519 → 50,497 |
| Mean locality | 76.3345 → 76.3993 | 76.8129 → 76.8246 |
| Mean leverage | 36.3481 → 36.6041 | 32.7339 → 32.9532 |
| Clone groups | 114 → 109 | 151 → 146 |
| Clone-covered lines | 1,660 → 1,575 | 2,199 → 2,114 |
| `var` properties | 441 → 437 | 470 → 466 |

Tracked code (including tests, canonical TypeScript, generated outputs and other
source languages, excluding prose): **56,664 → 56,656**, eight fewer lines.
Documentation/evidence is not included in that code count. Tests were added, not
pruned. Unused-ID findings fall 1 → 0; unreachable exports fall 2 → 1.
Unused-component findings stay zero (module exports are a separate category).
`ignoreUnknownSignals` stays zero; lint disables stay 15. Overall Lens score
remains **83**.

## Validation and limits

- Actual Qt interaction tests cover recovery command discovery, independent
  retry/discard guards, parent disablement and exclusion from field Tab traversal.
  Existing Clipboard/Bluetooth failure-and-retry and notification reply/history
  tests exercise domain acknowledgements and late responses.
- Added animation-completion signal regression and legacy-width normalization
  assertion. IP tests assert the first invalid address/overflowing octet, including
  earlier malformed tokens; an additional deterministic differential experiment
  matches baseline diagnostic results for **25,152** input/flag combinations.
- Strict lint and runtime smoke pass. The matched baseline has **261 Qt passes**;
  the result has **263 passes, zero failures/skips**, both directly and through
  Lens. Packaged imports, generated TypeScript parity, provider normalization
  (two checks), IP validation (61 checks) and `git diff --check` pass.
- The complete sibling-daemon Nix gate was attempted, but the final run exceeded
  its **600-second limit** while rebuilding sibling daemon dependencies. It was
  stopped; the complete gate is **unverified**, not passed. The runner needed
  Cargo/Rust added to PATH and new source/review files staged for snapshotting.
- Full Lens runs report zero verified/semantic failures, 109 formatting drifts
  on both sides, and 748 → 744 review findings. These are review data, not a
  replacement for the authoritative checks.
- Lens is **incomplete**, not a release pass: unresolved binding side-effect
  targets, the existing tray-mock `qmlformat` execution error, partial coverage,
  and two existing parser-oracle disagreements remain. The frozen baseline also
  lacks the ignored qmlbench JSON available in the live tree; no performance
  comparison is inferred from that difference. Do not suppress limitations or
  mistake a high heuristic score for verification.
- Offscreen tests do not prove hardware-input, live-compositor or screen-reader
  acceptance. No deployment or live backend mutations were performed.

## Evidence and reproduction

Ignored artifacts live in `target/lens-maintenance-2026-10-06/`: original
`baseline.tar`, frozen `baseline-tree/`, `concurrent.patch`/`.sha256`,
`snapshot.mjs`, `matched-before-*`/`after-*`, full `*-tools/` reports and logs,
`differential-ip.cjs`, and `sibling-gate.log`. The original unmatched baseline is
also preserved; it must not be compared directly with concurrent feature work.

```sh
node target/lens-maintenance-2026-10-06/snapshot.mjs matched-before \
  target/lens-maintenance-2026-10-06/baseline-tree
node target/lens-maintenance-2026-10-06/snapshot.mjs after
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all \
  --config target/lens-maintenance-2026-10-06/after-tools.config.json
tests/run-qmllint.sh
tests/run-qml-tests.sh
tests/run-runtime-smoke.sh
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
node tests/check-ip-validation.js wifi/networkinput/IpValidation.js
node tests/check-packaged-imports.js .
node tools/build-typescript.mjs --check
tests/check-sibling-boundary.sh
git diff --check
```
