# Five-stage QML quality pass

Baseline: `cd6fe15` plus the pre-existing working tree. Local Lens 0.5.0 uses the
unchanged `qmlqualitylens.config.json`; artifacts/logs are under ignored
`target/lens-next-five/`. Each stage is validated and committed independently.
Unrelated edits and staged documentation removals are excluded from every commit.

Priorities: destructive confirmation validation, Updates history ownership,
Bluetooth saved-patch validation, shared chooser restoration, and system chooser
view locality. Generated protocol validation belongs to sibling daemon-framework
and is deliberately not hand-edited to improve a score.

## 1. Notification delete confirmation

`NotificationValidation` now owns the bounded wire shape and exact app/record
scope checks. `NotificationState` keeps generation/view ownership and releases
rejected or late tokens in one place, without retiring a newer preparation.
Empty tokens now fail closed, consistently with the shared nonempty-token rule;
count/expiry/scope guards, explicit confirmation and no-replay policy remain.

- `finishPrepareDelete` cyclomatic **17 → 9**, cognitive **19 → 8**, weighted
  effort **72 → 37**. Helpers remain included in project measurements.
- Actual Qt center suite: **14 passed**, strict qmllint: pass.
- Added malformed/expired/wrong-scope token and late-generation regressions;
  retained native row-command, Escape-cancel and Tab/Enter-confirm journeys.
- Interaction contract: no new field stops, commands or automatic deletion.
  Rejected tokens are released, never accepted as permission to delete.

## 2. Exact-run history ownership

`UpdateController.acceptRunPage` separates exact-link outcomes from paged history:
only the requested single identity can publish; unreadable targets remain selected
for explicit retry; genuinely missing targets return to recent history. Empty-run
handling shares one retirement point. Wire validation, one stale-cursor restart,
continuation staging and atomic publication are unchanged.

- `finishHistory` cyclomatic **21 → 14**, cognitive **22 → 15**, effort **102 → 66**.
  Including the new helper: **20 / 21 / 100**, versus **21 / 22 / 102** originally.
- Actual Qt Updates suite: **38 passed**, strict qmllint: pass.
- Added unrelated/mixed/unreadable exact-link replies retaining cached rows without
  opening or requesting unrelated history; retained missing-link, stale-cursor,
  continuation, filter-key and selection/viewport journeys.
- Interaction contract: read-only inspection still cannot run an update. No key,
  field, focus-restoration or request-ownership changes.

## Measurement limits

Lens metrics are advisory, not developer-hour or correctness estimates. Source
counts include tests; generated files and analysis configuration are unchanged.
Clone reports may be partial/capped and cannot establish exhaustive deduplication.
Offscreen Qt tests do not certify live compositor, hardware, IME or screen-reader
behavior. No test exclusions, new skips or suppressed findings are introduced.
