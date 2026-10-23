# QML / Rust boundary: first migration

Runtime policy belongs to Rust; QML keeps presentation, input transactions and
small transport adapters. This tranche spans the `shelllist`, `bar-daemon` and
`clip-daemon` sibling worktrees; it does not port all remaining JS/TS or Python.

## Material roles

`bar-daemon/src/theme.rs` owns pinned `material-colors` Tonal Spot generation,
including Shelllist's success/warning tones and the existing 2021 container-text
semantics. `theme.configure({seed: "#rrggbb", dark: bool})` publishes the complete
role-to-hex map on `theme.changed`; `theme.resolve` returns a preview without
publishing. Both return `data.theme`. Startup subscriptions, `bar.snapshot` and
gap recovery use the same `snapshot.theme` projection. These are additive bar-api
methods/streams; generated contracts and producer fixtures are updated together.

Qt still observes desktop accent/mode and sends preferences. Shared
`Io.MaterialTheme` retains the last complete map and resends preferences on
reconnect. `Ui.MaterialPalette` only binds roles. `ThemeDefaults` contains two
fixed startup/offline maps, checked against native fixtures, not a JS fallback
engine. The development gallery uses read-only previews. The npm adapter,
5.7k-line generated JS engine and esbuild derivation/dependency are removed;
Node remains necessary for unrelated existing frontend tooling.

## Ranking

Every generic ResultStore query, including empty and cleared queries, goes through
`shelllist-search`. `Model.js` no longer normalizes search text, scores matches or
sorts results. Rust owns score, provider-priority, normalized-title and key ties;
fractional model scores remain valid. Native provider-ranked windows retain their
supplied order rather than being ranked again.

While pending, retain the accepted keyed window (even an empty one); only startup
may show source order. Clearing now waits for Rust instead of sorting immediately.
Owner/generation fences and stable selection remain. Reconnect replays live
catalogs/latest queries, and release retires abandoned work. Clipboard's vendored
matcher stays byte-identical to the shared source and uses the widened score type.
See the mandatory [keyboard contract](chooser-keyboard-workflow.md).

## Performance tools

The Python profiler/resident/responsiveness scripts are removed. Their supported
workflows are `shelllist-perf profile-qml`, `resident --check`, and
`run warm-open --check`; `check --run` evaluates existing evidence. The small
`tests/profile-qml.sh` wrapper only adapts QMLQualityLens's CLI. The Nix developer
package/check now builds the Rust tool, not a Python adapter test.

Collectors, PID-targeted IPC, process-group cleanup and artifact validation are
shared with the existing Rust lens. Native profiling preserves source hashes,
bounded streaming XML, stale-source rejection and failure cleanup. Active trials
require explicit consent and never hide an unowned panel. Cold readiness is only
reported when actually observed; latest search/model values are not fabricated
as per-open metrics. See [commands and measurement limits](../tools/performance-lens/README.md).

## Native domain policy: partial second migration

This follow-up spans `shelllist`, `bar-daemon` and `nm-daemon`:

- `bar-daemon/src/battery/history_chart.rs` projects observed-time windows, valid
  zero versus missing power, discontinuities and newer live observations.
  `battery.history({hours: 6 | 24 | 168})` adds `hours` and `chart` to the existing
  response; omitted hours defaults to six. QML keeps painting, formatting and
  pointer inspection. Enter/Tab saves the range and requests a read; Escape
  discards without requesting. Superseded replies cannot publish.
- `bar-daemon/src/display_policy/layout/draft.rs` decodes raw preview drafts,
  rejecting empty/nonfinite/fractional integer buffers and unknown fields. Only
  known presentation metadata is ignored; the native output catalog remains
  authoritative. New independent-output overlaps are rejected before persistence
  or compositor writes; unchanged observed overlaps and actual mirrors remain
  supported. `DisplayModel.js` no longer owns draft validation or wire payload
  construction. It retains local draft/map geometry and placement affordances.
  Explicit Preview is now the validation boundary, not a promise of acceptance;
  rejected raw drafts survive for correction and explicit retry. Baseline, trial,
  last-display, confirmation and rollback guards remain native.
- `nm-daemon/src/daemon_runtime/health_feedback.rs` moves the remaining health
  feedback suppression into native per-consumer fan-out: active owned connections
  and a monotonic three-second duplicate window. Owner loss retires that state.
  Existing native classification/correlation stays in place. QML renders only
  the recommended native message; `wifi/NetworkHealth.js` is removed.

**Not migrated in this pass:** BluetoothFlow scan/rescan/request policy,
WifiPromptPolicy enterprise/secret/validation policy, UpdateValidation and
Model.js provider-schema validation. Their existing checks remain intact; this
is not completion of the entire domain-boundary request. In particular,
malformed-reply checks must move to protocol-owned schemas, not be deleted.

Second-migration checks: 267 Qt passes, zero failures, one existing renderer
skip; strict QML lint, generated-binding/contract checks and both changed native
crates' all-target Clippy checks pass. Bar library:
206 passes and three existing ignored tests. NM library: 88 passes and three
existing ignored tests. Added evidence covers native projection and draft
rejection, zero writes/trials on overlap rejection, health owner isolation,
actual range keys, late range replies and retained failed display drafts.
No numeric UI-role overrides were added. Producer fixtures were refreshed,
including the previously stale Shelllist copy of the bar contract.

Root `nix develop` could not build its performance-lens dependency: CLI tests
`descriptive_compare_requires_matching_context` and
`changed_scopes_preserve_all_other_comparison_guards` failed. Qt checks used the
available runner; native checks used the sibling daemon dev shells. Full Nix
packaging, live health feedback and physical display/battery acceptance remain
unverified. No services, hardware settings or deployments were changed.

## First-migration validation checkpoint

- Native QML suite: 263 passes, no failures, one existing renderer skip; strict
  qmllint and generated-contract checks pass.
- Rust search: 9 tests pass (two existing manual probes ignored); clipboard's
  native history-search test passes with its vendored copy.
- Bar-daemon library: 200 tests pass (three existing manual probes ignored),
  including exact old-generator palette parity and stream/snapshot consistency.
- Performance lens: 48 unit, 11 CLI and two profiling-process tests pass; three
  existing manual/load-helper tests remain ignored. Rust search/lens Clippy pass.
- The Rust profiler completed a real offscreen Qt run and emitted source-hashed
  observations. This is not a live display-frame or performance-budget result.

Full sibling-aware Nix packaging/deployment, live desktop theme changes, real
resident budgets and consent-gated live responsiveness measurements remain
acceptance gates. No user services or hardware settings were changed.
