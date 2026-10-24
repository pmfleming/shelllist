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

## 3. Bluetooth saved-patch normalization

`BluetoothAdapterEdits.savedChanges` is a side-effect-free all-or-nothing conversion
of saved fields. Submission now owns only availability/pending/error guards and
request capture. Normalization leaves raw drafts intact for partial acknowledgement
and explicit retry. Both edit admission and conversion reject inherited map names
such as `toString`, rather than treating them as supported wire fields.

- `saveBatch` cyclomatic **14 → 8**, cognitive **17 → 7**, effort **72 → 37**.
  Including normalization: **16 / 19 / 80** (a small aggregate increase for the
  explicit validation boundary/allowlist); maximum cognitive falls **17 → 12**.
- Actual Qt Bluetooth recovery suite: **9 passed**, strict qmllint: pass.
- Invalid aliases/timeouts/foreign fields cannot emit a partial patch or enter
  pending state. Existing partial-ack/retry coverage now also checks trimming and
  rounding without rewriting the retained raw draft.
- Interaction contract: field-local drafts still enter the owner only on save;
  no per-keystroke writes, automatic retries or acknowledgement changes.

## 4. Shared chooser restoration interruption

`ChooserSession.interruptRestore` owns the common pending/restoring predicate for
region, search-selection, popup, native-focus and cursor events. Event-specific
conditions stay at their callers: applying presentation memory is still exempt
where it was before; explicit suspension/disable/interaction still cancels directly.
No reactive cancellation binding or second restoration state was introduced.

- Entire component function/handler sums: cyclomatic **104 → 98**, cognitive
  **86 → 79**, weighted effort **426 → 407** (including the new helper).
- Native chooser memory **5 passed**, keyboard **4 passed**, strict lint: pass.
- Added real Escape/printable-search navigation while readiness is pending;
  late readiness cannot steal focus, resume editing or publish a field write.
- Interaction contract: restoration never restores unsaved values; explicit user
  navigation wins over deferred restoration. The retained readiness case still
  proves that uninterrupted restoration resumes editing and saves only on Enter.

## 5. System chooser detail locality

`SystemChooserDetails` is an internal domain view built from the same shared
`ActionDetailsPane`, `DetailFlickable`, `FormField`, toggle and command controls.
The parent now owns only list/menu lifecycle and supplies one typed controller
plus the resolved identity icon. No parent-object escape hatch, callback registry,
extra Loader or local setting-control wrapper was added. Translation contexts,
editor object names, hierarchy within details, spacing and guards are retained.

- Surface source lines **252 → 140**; extracted details **120**. Surface binding
  count **124 → 56** and fan-out **18 → 8**; details have **70** bindings.
- Locality **0 → 49** for the surface; **51** for the new details component.
  The component effort sum increases **395 → 414** with the explicit boundary;
  this is a locality improvement, not a free abstraction or runtime speed claim.
- Actual Qt system chooser suite: **10 passed**. New native traversal skips passive
  artwork, retains a mode draft across metadata arrival, discards on Escape, saves
  on Tab to the inspected player and waits for acknowledgement.
- Full Qt suite: **373 passed, 0 failed, 1 existing renderer skip**; strict lint,
  source-relative import check and native offscreen runtime smoke: pass.
- UI drift review: no numeric-style/new-wrapper prompts. The extracted view was
  also reviewed directly: all dimensions/roles were moved unchanged, owned by the
  shared UI/system chooser maintainers. No new appearance exception is introduced.
- Interaction contract: Media pin/mode remain the only editable controls there;
  Audio mute and independent commands retain their guards. The shared surface
  still owns all browsing, field transactions, modal guards and session memory.

## Combined outcome

Baseline → stage 5, production only (excluding `tests/` and `dev/` in this summary,
not in Lens discovery): source **39,811 → 39,836**, function/handler cyclomatic sum
**9,247 → 9,246**, cognitive sum **6,491 → 6,484**, weighted effort sum
**40,616 → 40,614**. Full configured source including regressions increases
**48,868 → 49,021**. These five changes prioritize explicit safety boundaries and
locality rather than claiming a net line-count reduction. No tests were removed.

Whole-project locality **76 → 77**, overall **83 → 83**, leverage **33 → 33**;
findings **946 → 943**. The local complexity reductions are substantially larger
than the rounded project scores. No exhaustive clone reduction is claimed.

Validation does not include a full Nix/package build, sibling-daemon tests, live
hardware or human accessibility review. The smoke runner retains the offscreen
window-mask warning. Source-import checking is not installed-package acceptance.

## Measurement limits

Lens metrics are advisory, not developer-hour or correctness estimates. Source
counts include tests; generated files and analysis configuration are unchanged.
Clone reports may be partial/capped and cannot establish exhaustive deduplication.
Offscreen Qt tests do not certify live compositor, hardware, IME or screen-reader
behavior. No test exclusions, new skips or suppressed findings are introduced.
