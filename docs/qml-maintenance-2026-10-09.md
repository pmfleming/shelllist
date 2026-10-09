# QML Lens review — catalog and shared-label cleanup

## Scope

Clean baseline `a910ac5d`; local `../qmlqualitylens` 0.5.0 (`6868f2f`),
Node 24.16.0 and Qt 6.11.1. The repository configuration's source roots,
entrypoints and dynamic edges are unchanged. Temporary static configurations
set `tools` and `reports` to `{}`; native checks run separately, so stale imported
coverage cannot imply verification. No thresholds, suppressions, source exclusions
or test-discovery rules changed.

## Findings and changes

1. **Dead notification detail reader.** `NotificationCatalog` retained selected
   records, page editing, a second request generation and full-record validation
   after the center removed its Message page. Repository-wide callers were only
   obsolete test fixtures; production never assigned `selectedKey`. Remove that
   reader and its unused `loaded` flag. Catalog completion now owns app-group
   windows only, with one explicit view/query/generation guard before retiring a
   read. Keep atomic staging, epoch/revision fences, queued-event flushing, cursor
   recovery and all mutation acknowledgements. `NotificationTimeline` still owns
   previews/periods; the controller's explicit `view: "app"` group-resolution
   request remains independent. No daemon API or popup reply behavior is removed.
2. **Cloned dropdown label composition.** Closed values and popup options repeated
   text sizing, padding and decorative leading/trailing glyphs. Internal
   `qml/Shelllist/Ui/DropDownLabel.qml` shares that composition across both owners.
   Saved checks, candidate highlighting, error colour, reserved check space,
   accessible identities and `ChoiceEditSession` remain unchanged. Its aliases
   expose local typed glyph objects, not dynamic callbacks or another key model.
3. **Unused toolbar and IDs.** `ActionToolbar` had no constructions/references in
   repository or sibling QML sources beyond its qmldir registration. Remove it
   and its obsolete field-Tab opt-in; live commands still use `SurfaceActionRow`.
   This is an internal application toolkit, not a promised external API. Remove
   seven unused IDs, retaining all `objectName` values. The remaining cleanup
   finding is the enum-only SystemTray test mock, which is not dead code.

## Measurements

Production excludes `tests/` and `dev/` but includes generated JavaScript;
all-source metrics include tests and development fixtures in both runs.
Function complexity/effort figures are sums of Lens records. Weighted `effort`
is **not Halstead effort or developer time**. Locality/leverage are unweighted
component means; their small gains are advisory, not a productivity claim.

| Metric | Before | After |
| --- | ---: | ---: |
| Production source LOC | 39,845 | 39,713 |
| All-source LOC | 50,129 | 49,995 |
| Production function cyclomatic sum | 7,984 | 7,936 |
| Production function cognitive sum | 5,495 | 5,455 |
| Production function weighted effort sum | 39,506 | 39,300 |
| Production component effort sum | 45,358 | 45,119 |
| Production mean locality | 75.54 | 75.66 |
| Production mean leverage | 37.85 | 37.95 |
| Expanded normalized clone groups, all sources | 159 | 157 |
| Structural clone groups, all sources | 36 | 35 |
| Cleanup findings | 9 | 1 |
| Production `property var` declarations | 465 | 462 |

Net physical code change is **−144 lines**, including the new component, qmldir
registration and regression tests, excluding documentation. Dynamic declarations
fall by deleting unused state, not by disguising JSON as typed QObjects. No lint
suppression, dynamic lookup or compatibility escape was added. All-source function
sums also fall: cyclomatic 8,872 → 8,816, cognitive 5,886 → 5,840, weighted effort
47,211 → 46,980.

Catalog `receive` falls 14/14/62 → 13/12/54 (cyclomatic/cognitive/weighted effort),
with its obsolete `ownsRead` branch function removed as well. Its separately
measured Halstead effort falls 4,669.62 → 3,261.95. Catalog locality rises 80 → 92;
dropdown 22 → 37; option delegate 62 → 77. The shared label has two observed
consumers and locality 87. Overall rounded Lens score remains **83**.

Default clone output is capped at 100 normalized groups. The supplementary scan
uses the same six-line detector with limits of 500,000 keys, 5,000 windows/key and
5,000 groups; both scans complete with zero omitted windows/groups. Similar
syntax is not proof of interchangeable behavior. Parser diagnostics are zero,
but the Lens contract remains **incomplete** on unresolved binding side effects;
static findings and scores are not native correctness evidence.

## Validation

- Warning-fatal QML lint: pass.
- Full Qt baseline: **360 passed, 1 failed, 1 skipped**; after: **365 passed,
  1 failed, 1 skipped**. Counts include lifecycle hooks. Both fail identically in
  `ApplicationResources::test_missingIntervalsHaveNoDashedPaint`, line 376:
  activity pixel `#574d4f` versus expected `#31282a`. The existing RHI-only media
  artwork skip remains. **The full suite is not green.** No failure/skip was hidden.
- Focused native suites: Notifications 26/0, NotificationCenter 25/0 and
  FieldInteraction 19/0. Five ownership rows replace the unused reader's test;
  foreign-record validation is tested on the actual timeline. Existing native
  search, tabs, delete confirmation, policy transactions, paging and stale-response
  tests remain. Dropdown pointer tests now also check passive icons, saved versus
  candidate state, shared padding and reactive icon removal through save/discard.
- Native offscreen runtime smoke: pass, with the platform's window-mask warning.
- Packaged-relative-import, daemon-boundary, notification-presentation,
  application-resource and resource-availability JavaScript checks: pass.
- TypeScript generation/type checking: pass. `git diff --check`: pass.
- Panel UI review: zero changed-line numeric-role or new-wrapper prompts. The new
  untracked shared label was inspected separately: existing Theme roles only,
  no setting wrapper or new numeric font/spacing/radius override.

No full sibling-aware Nix build, profiler/coverage, visual capture matrix, live
hardware, screen-reader or IME acceptance was run. Shared offscreen tests do not
substitute for those gates.

## Follow-up priorities

- Applications owner: diagnose the reproducible baseline resource-pixel failure
  before claiming a green release gate; unrelated plot behavior is unchanged here.
- Notification timeline `receive` (30/30 cyclomatic/cognitive), Bluetooth backend
  `finish` (25/34), and application operation `apply` (29/30) remain hotspots.
  Their acknowledgement and recovery branches need cohesive ownership changes,
  not mechanical function splitting or erased validation to improve scores.
- Generated Material colour complexity belongs in its generator/upstream library;
  do not hand-edit generated output.

## Reproduction

Ignored evidence lives in `target/lens-refactor-current/`, including static configs,
`before/` and `after/` reports, expanded clone scans, `compare.mjs`, native logs and
panel-review output. `compare.mjs` reconstructs the clean baseline using Git,
resolving module symlinks to tracked paths; it includes the new label in the final
source scope. To regenerate static evidence, copy `qmlqualitylens.config.json`,
set an absolute `project_root`, a fresh `output_dir`, and `tools`/`reports` to `{}`:

```sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config <static-config>
tests/run-qmllint.sh
tests/run-qml-tests.sh
tests/run-runtime-smoke.sh
node tests/check-packaged-imports.js .
node tests/check-daemon-boundary.js .
node tests/check-notification-presentation.js qml/Shelllist/Ui/NotificationPresentation.js
node tools/build-typescript.mjs --check
python3 tests/review-panel-ui.py --base a910ac5d
```
