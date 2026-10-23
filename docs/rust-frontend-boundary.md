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

## Presentation data migration

The named presentation-table families now have readonly QML singleton data:
`BatteryPresentation.qml`, `WeatherVisuals.qml`, `BluetoothGlyphs.qml`,
`WifiIcons.qml` and `Ui/MaterialIcons.qml`. Their JS table modules and the weather
TypeScript source/generation entry are removed. Unknown keys cannot resolve
inherited object members. Wi-Fi uses native `security_class`, without a second
flags/security-string classifier; Bluetooth's native snapshot now includes
`icon_id`, with its old metadata precedence tested in Rust. Missing classifications
use generic/unknown artwork, not frontend inference.

- Bar's battery projections supply forecast/history duration labels, plot-axis
  labels, inspected readings, percentages, watts, battery Wh and protection-range
  labels. App-daemon's energy overview supplies `energy_label` and
  `total_energy_label`, preserving unavailable versus valid zero.
- Bar's activity projection supplies weather units, compass labels, future-hour
  selection, normalized chart ranges, daylight duration/fraction, sun progress,
  location accuracy units and IANA-derived `clock_display` time/date/offset labels.
  A minute-aligned native publication loop is independent of forecast I/O and
  retains existing source errors. Shared keyed city updates preserve delegates,
  selection and open picker drafts; no frontend clock timer or polling is added.
  Missing display metadata stays unknown; disconnected views retain the last
  native reading rather than extrapolating it.
- Framework `fixed_decimal` preserves the former decimal-label rounding,
  including exact ties and binary values such as 2.55, without adding a dependency.
  QML retains pixel placement, gradients and the lunar-disc paint silhouette of a
  native phase, not numerical measurement/astronomical estimates.

`BatteryFeedback.js` contains remaining local pending/error text composition;
existing draft admission checks remain in `BatteryFlow.js`. Those guards and all
save/discard, acknowledgement, retry, authorization and hardware safety behavior
are unchanged. This is the named presentation-family migration, not a claim that
unrelated Media/Updates/Application presentation adapters or the pending domain
policies above have all been ported.

Producer fixtures and generated app contracts change additively with these native
fields. Ship the matching framework, bar/app/Bluetooth daemons and QML together.
No additional typography, spacing or radius overrides were introduced; moved
143/66px forecast geometry and the lunar silhouette remain owned by their existing
chart components, with unchanged dimensions. Native Qt tests cover asset fallbacks,
verbatim native labels, missing projections and clock updates during an open city
picker. Validation: **273 Qt passes, zero failures, one existing renderer skip**;
bar library **213 passes**, app library **41 passes**, Bluetooth library **65
passes**, framework core/generator **13 passes**. Existing native ignored probes
remain unchanged. All changed Rust crates pass all-target Clippy; QML lint,
TypeScript generation checks, producer fixtures and generated-contract checks pass.
Full sibling Nix packaging and live desktop/hardware acceptance remain separate
gates; no deployment or service changes are performed by this migration.

## Rust development tooling

`cargo xtask` in `tools/xtask/` now owns surface catalog generation/freshness,
build-input auditing, standalone Cargo cache trimming and offline fixture parity.
The replaced Python tools/tests, jq assertions, shell API contract checks, and
Node boundary/validator checks are removed. Nix invokes the Rust tool. See
[`tools/xtask/README.md`](../tools/xtask/README.md) for commands and safety scope.

App, bar, Bluetooth, clipboard and NetworkManager own the Rust contract tests:
fixtures decode using their actual serde DTOs, with malformed-type regressions
and retained semantic assertions. No parallel frontend-shaped Rust DTOs are
invented. Bluetooth audio gained a shared live wire DTO; its fixture was missing
endpoint metadata already emitted in production. Clipboard gained an explicit
history-page witness. Registry/envelope projections that remain dynamic retain
semantic checks. Frontend copies, method coverage and NM's API rendering are
checked separately by xtask. Output-only deserialization is test-only.

Transport ownership/recovery and IP-validation regressions now run against actual
Qt/QML objects, driven by xtask, instead of extracting functions into Node. This
does not migrate or weaken IP editing policy or introduce backend writes. Cache
cleanup requires `--apply`; dry runs and temporary-fixture tests preserve the
Cargo-lock, symlink, tracked/source, nested-repository and artifact-scope guards.
The separately packaged update-daemon maintenance service is unchanged.

Validation: **19 xtask tests**, **323 Qt passes** (one existing renderer skip),
and **450 daemon library passes** (nine existing ignored probes). One existing NM
private-bus activation test timed out during concurrent builds, then passed an
isolated retry and the full suite unchanged. All-target Clippy passes for xtask,
app, bar, Bluetooth and NM; clipboard's production library passes, while
its tests still emit the pre-existing unused `CachedProjection::project` warning.
QML lint, fixture/binding freshness, generated runtime contracts and TypeScript
checks pass. The UI advisory reports zero new prompts.

A sibling-aware Nix xtask package/build-input check passed before the final private
NM-log regression was added. The final Nix surface/build-input recheck is blocked
by an unrelated untracked worktree document; snapshot preflight is not bypassed.
Full sibling packaging remains a separate gate. No real cache cleanup, deployment,
service or hardware changes were performed.

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
