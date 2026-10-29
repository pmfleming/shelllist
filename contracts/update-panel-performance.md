# Update panel rendering contract

Updates remains read-only. Page creation, scrolling, status disclosure and tab
changes never request a release check, install, approval or retry. Controller
request ownership, validation, cached-log behavior and settings transactions are
unchanged.

## Bounded presentation

- `UpdateDetails` asynchronously loads the selected settings, overview, run
  summary, changes or log content. Applications is a separate viewport-sized
  page, not a list nested in the ordinary detail Flickable. Inactive overview
  domains do not instantiate their cards, tool rows or schedules.
- `UpdateApplications` uses shared `DetailListView`, `SerializedListModel`,
  `FieldRow` and feedback composition. Only the viewport and a bounded reuse pool
  have delegates, even with the supported 512-package inventory. There is no
  all-packages Repeater or content-height-sized ListView.
- Keys include scope, name, installed version and an occurrence discriminator.
  Multiple versions of one package must not collide; even repeated identical
  records accepted by the wire validator remain representable. Latest-release
  changes do not change installed-package identity.
- Pooled rows are hidden from shared command discovery. Reused row commands bind
  to their current package; status feedback belongs to the page, not a delegate.
  Evidence replacement and page closure clear disclosed explanations.
- Heading Help and instantiated row status commands remain available through
  Alt+J, never as editable stops. PageUp/PageDown exposes further package rows
  and their commands. Tab uses the shared non-highlighted scrolling fallback;
  Up/Down still selects history results. Ctrl+Tab switches pages without reads.
- Refresh brackets keyed viewport capture/restoration. Shared `DetailListView`
  remembers a row key and pixel offset as well as its legacy scroll value, so
  recreating a lazy page does not depend on ListView's initial height/origin
  estimate. Missing keys fall back safely. User navigation cancels pending
  anchoring. Delegate inspection is deferred outside contentY notifications.
- Shared `FieldRow` tolerates retirement before asynchronous construction has
  completed; it must not dereference a destroyed editor host.

## Regression owners

`tests/qml/tst_updates.qml` exercises the actual panel with recording transports:

- no inactive application/system/tool/log trees;
- fewer than 40 instantiated package identities at both 193 and 512 packages,
  including scrolling to the end and returning after page destruction;
- native Tab/PageDown, result navigation, pointer status disclosure, pooled
  command exclusion and retained keyed viewport on refresh;
- same-name/multiple-version and identical-record key uniqueness;
- existing Alt+J disclosure, fixed feedback geometry, malformed/unavailable
  evidence, log ownership, settings save/discard and exact-run routes.

`tests/manual/tst_update_performance.qml` is a non-gating synthetic timing probe:

```sh
tests/run-qmlquality-tests.sh -input tests/qml/tst_updates.qml
tests/run-qmlquality-tests.sh -input tests/manual/tst_update_performance.qml
```

Wall-clock thresholds are deliberately not CI assertions. Structural bounds and
interaction behavior are. Shared chooser-memory, keyed-update, field-interaction
and notification-center suites cover the shared consumers.

## Local evidence (2026-10-29)

Qt 6.11.2, offscreen software renderer; before/after observations use the same
local harness. Times are samples, not live-compositor latency guarantees:

| Operation | Before | After |
| --- | ---: | ---: |
| Assign actual cached overview while Applications is hidden | 6,997 ms | 89 ms |
| Assign synthetic 193-package overview | 4,360 ms | about 25–33 ms |
| Assign synthetic 512-package overview | 26,378 ms | about 23–29 ms |
| Open Applications with 193 / 512 synthetic packages | eager population already paid | about 78 / 109 ms to ready |

The synthetic full panel has 743 visual items with Applications open at either
193 or 512 packages, rather than scaling with the inventory. The old 193-package
synthetic hidden page alone added 6,176 visual items. Live read-only daemon calls
were about 13 ms for history and 28 ms for overview; no backend changes were
needed.

Validation:

- Complete Qt suite: **670 passed, 0 failed, 1 existing RHI-only artwork skip**.
- Updates suite: **41 passed** on Qt 6.11.2 and deployed-version Qt 6.11.1.
- Strict lint of changed production QML: pass. UI role review: zero prompts;
  shared typography, spacing and radii remain in use.
- Update capture fixture: **6 passed**, light/dark at 1040×720 and 976×600;
  reviewed application layouts with deployed font configuration and Qt 6.11.1.
- Synthetic timing fixture: **5 passed**. Counts include lifecycle hooks.

Ignored measurements/logs live in `target/update-performance/`; captures are in
`target/update-panel-implementation/captures/`. Actual cached reports remain
local and are not committed. No updater mutation, service restart, deployment,
hardware or human screen-reader acceptance was performed.
