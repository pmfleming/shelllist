# Post-surface QML maintenance

## Scope and provenance

This review follows the [Material surface follow-up](material-surface-follow-up.md).
Baseline: clean Shelllist `4ad8d58d73a74b673d00f1e508feb67abdac1839`.
Tool: local qmlqualitylens 0.5.0 at
`80cb7a94191a40f6db8cf5571cd4a1fb5c1f7115`, Qt 6.11.1.
The unchanged configuration SHA256 is
`25ed258faf45a547b55e581a1c92a75ad6d8e11805284c8763567cecbebadacb`.

Reviewed Wi-Fi, Bluetooth, Clipboard, Applications, the bar and their shared
provider/action/navigation components. This is a bounded maintenance pass, not a
replacement for domain-owned recovery or the existing surface architecture.

## Implemented

- Removed `GlanceWeatherCard` and `GlanceNotificationsCard` and their module
  exports. Neither has a remaining construction site after Activity became
  schedule-only. Standalone weather/notifications and their state owners remain.
- Added pure `Core.Model.visibleActions`: visibility and optional presentation
  grouping share one definition. Disabled actions, descriptor identity and order
  remain intact; unnormalized toolbar descriptors can specify a fallback group.
  Model primary-action validation, `DetailsHeader`, `ActionToolbar`, Wi-Fi profile
  settings and Bluetooth settings use it. Bluetooth's multipoint exclusion stays
  domain-local. Headers cache primary/toolbar projections rather than repeating
  filters for primary, stacked and inline layouts.
- Audio volume and Tray body actions reuse `ActionToolbar`. Optional labels and
  object-name prefixes preserve their existing appearance, accessibility and
  navigation identities. Clipboard and Applications benefit through the shared
  header/toolbar rather than receiving another domain-specific renderer.
- Typed `SystemChooserController.trayItems` as `list<SystemTrayItem>` instead of
  an untyped QObject-list value. JSON DTOs and genuinely dynamic values remain
  `var`; a smaller count alone is not justification for incorrect types.
- Simplified Bluetooth device visibility into blocked/known/discovery decisions,
  removing two redundant predicates. Pairing prompt replacement copies the queue
  and replaces one slot instead of mapping a conditional over every item. Ordering,
  first-match replacement, prompt/device identity and old snapshots are preserved.
  Canonical TypeScript owns the generated JavaScript change.
- Removed the obsolete native-only `NotificationQuickActions.activeFocusInside`:
  production already uses the combined native/browse `focusInside`. Its regression
  now asserts actual native focus plus combined feedback, then independently
  verifies browse-only feedback cannot activate an action.

No capabilities, effect routing, acknowledged state, drafts, leases, preview
rollback, native-menu lifetime or presentation-memory ownership were generalized.
Clipboard failure recovery, Wi-Fi credential/partial-save flows, Bluetooth
operation correlation and launcher resource-history merging retain their domain
logic. Their apparent similarities do not justify a generic state machine.
The remaining cleanup candidates (six palette entries and four test doubles)
were retained; exported/dynamically consumed objects are not proven dead solely
by a low consumer count. No contracts, assertions or suppressions were relaxed.

## Measurements

Same source discovery/configuration on both sides. Production excludes tests and
`dev/`; “all” includes those Lens inputs. These are heuristic structural metrics,
not runtime measurements or proof of correctness. Canonical TypeScript and Node
policy tests are included in the separate tracked-code total, not these QML/JS
Lens aggregates.

| Metric | Production before | Production after | All before | All after |
| --- | ---: | ---: | ---: | ---: |
| Cyclomatic complexity | 7,996 | 7,984 | 8,583 | 8,573 |
| Cognitive complexity | 9,475 | 9,472 | 9,769 | 9,768 |
| Function effort | 46,507 | 46,467 | 52,359 | 52,334 |
| Component effort | 43,978 | 43,476 | 53,044 | 52,556 |
| Mean locality | 75.4113 | 75.9286 | 76.7254 | 77.1682 |
| Mean leverage | 54.2695 | 54.4107 | 50.9015 | 50.9970 |
| Source LOC | 37,281 | 36,916 | 45,272 | 44,919 |
| Physical LOC | 41,707 | 41,311 | 49,995 | 49,611 |
| Normalized clone groups | 138 | 133 | 179 | 174 |
| Clone-covered lines | 1,983 | 1,902 | 2,628 | 2,547 |
| `var` properties | 429 | 424 | 459 | 454 |
| `ignoreUnknownSignals` | 0 | 0 | 0 | 0 |
| Lint disables | 15 | 15 | 15 | 15 |

Tracked physical code, including canonical/generated sources and regression
checks but excluding docs: **55,279 → 54,922**, a net reduction of **357 lines**.
Production component count: **282 → 280**. Most line and aggregate component-effort
savings come from deleting the obsolete previews; complexity gains are small.

Locality/leverage means are also affected by removing two components, not merely
by improved reuse. Individual trade-offs remain visible: `DetailsHeader` effort
172→158 but locality 32→30; `ActionToolbar` effort stays 75 and locality 92→89;
`ModelApi` effort 23→26. `SystemChooserContent` effort falls 457→435. The shared
abstraction adds a small dependency cost; it is justified by one presentation
contract and fewer repeated delegates, not by claiming every file improves.

Complete normalized-clone comparisons use 200,000 keys, 1,000 windows per key and
10,000 groups: **zero omitted windows/groups** on both sides and both scopes.
The ordinary configured audit's capped clone output is not substituted for these
complete scans. Heuristic score stays **83**; native-tool review findings fall
**1,035→1,017**. Cleanup reports zero unused components/IDs after manual removal
of the two obsolete exported cards (exports alone are not use evidence).

## Validation and limits

- Full sibling-aware `local-build.py check shelllist --keep-going
  --print-build-logs`: all checks passed; **300 Qt passes**, comprising 218
  behavioral cases and 82 setup/cleanup hooks. No test cases were removed.
- Fresh strict lint and Lens native lint: **387/387** files, no diagnostics
  (baseline 389/389; two deleted components).
- Fresh Lens test evidence independently records **300 passes, zero failures**;
  its static discovery count of 209 is not the executed behavioral-case count.
- Parser oracles pass: 335→333 files, no findings. Runtime-warning adapter passes.
- Bluetooth policy checks: **381 assertions**, including the visibility matrix
  and immutable queue replacement. Provider model: **11 checks**, including
  disabled-slot ordering, grouping defaults and null input.
- **1,024** frozen-input differential comparisons against the baseline cover
  Bluetooth visibility and requested/display/answered/cancelled/unknown events.
- Existing Qt tests additionally check body action names/labels/geometry and
  native/browse notification feedback without effects. The full gate checks
  generated TypeScript output, API contracts and existing recovery regressions.

The Lens verdict remains **incomplete**, not certified: the existing tray mock
`tests/qml/imports/Quickshell/Services/SystemTray/SystemTrayItem.qml` still fails
qmlformat with exit 1 and empty output. Formatting drift remains **80→80**;
no formatting failure was suppressed. Existing Fontconfig and asynchronous
engine-destruction diagnostics remain visible in native logs.
No matched performance baseline, live compositor/hardware, IME, screen-reader,
large-text or touch acceptance is claimed. Nothing was deployed or restarted.

## Reproduction and local evidence

From the workspace, with the established Qt environment:

```sh
source /tmp/shelllist-refactor-env
node qmlqualitylens/target/shelllist-maintenance/snapshot.mjs surfaces-after
python3 daemon-framework/tools/local-build.py check shelllist --keep-going --print-build-logs
cd shelllist
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
node target/lens-surface-maintenance/differential.cjs
```

Ignored local artifacts (not a portable release bundle):

- `shelllist/target/lens-surface-maintenance/baseline.tar`, `before-tools/`,
  `after-tools/`, `differential.cjs`.
- `qmlqualitylens/target/shelllist-maintenance/surfaces-{before,interim,interim2,after}*`:
  records, summaries and complete clone scans.
- `/tmp/lens-surfaces-{before,after}-tools.log`,
  `/tmp/lens-surfaces-full-gate.log`,
  `/tmp/lens-surfaces-final-{lint,tests}.log`.
