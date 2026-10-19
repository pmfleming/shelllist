# Time & Weather location implementation

Current design: [revision 5 HTML plan](time-panel-location-plan.html), including the
post-implementation Current-city and single-control picker clarifications below.

## Commit stages

1. Contract and execution record — complete, Shelllist `c92a4d5`.
2. Native saved-city catalog, fixed Amsterdam Home and at-home projection — complete, bar-daemon `aa65230`.
3. Authorized manual/automatic location authority controls and session API — complete, bar-daemon `376dba0`.
4. Shared panel icon commands, picker and confirmation — complete, Shelllist `a163bb6`.
5. Integration fixtures, broader native/Qt tests and documentation — complete,
   bar-daemon `582ecbb` and Shelllist `3aac074`.

Each completed implementation stage is committed in its owning repository.
Completion and validation are recorded below; a planned stage is not a claim of
implemented or tested functionality. Services are not activated by this work.

## Contract

- Home is protected Amsterdam, Europe/Amsterdam. Its fixed place/weather data
  never becomes the current estimated coordinates.
- Home has a passive house icon; Current has a target only away from Home. At home
  there is only Home: no separate Current row, Current icon, label or metadata.
  Current is single and populated, never a blank placeholder. Compare canonical
  timezone identity, not current UTC offsets; unknown location is not proof of
  being home and must not invent a city.
- Every city and both detail tabs share one Manual-location primary, then
  Automatic and Remove secondary commands. Disabled commands retain geometry.
- Add uses the existing search trailing icon. List Enter only inspects; command
  activation opens an explicit picker/confirmation. No writes while typing.
- Manual location chooses a place and its system timezone. Automatic is an
  explicit policy change, not an immediate claim of a fresh accepted location.
- The system authority remains the sole timezone writer. Persistence, verified
  acknowledgement, authorization and uncertain-write fences remain authoritative.
- Saved cities use native durable storage, separate from declarative config.
  Removal cannot be undone by the next config refresh. Same-zone cities remain
  distinct. Weather failure must not disable a valid city clock.

## Work preservation

At entry Shelllist had only the untracked approved HTML plan. The sibling
bar-daemon had pre-existing modifications to `docs/location-timezone.md` and
`flake.nix`; those changes are not owned by this task and must not be included
incidentally in stage commits.

## Validation record

Stage 1: source/design review; HTML local references checked. No runtime changes
or live timezone/provider operations.

Stage 2: locked native library: 154 passed, zero failed, one existing ignored
fixture. Native protocol regenerated. Service fixtures do not contact weather HTTP.
Stage 3: authority: 34 passed, zero failed, one existing ignored packaged-agent
fixture; library: 154 passed, zero failed, one existing ignored test. Private bus
covers real authorization denial/control/readback serialization; no host bus writes.
Stage 4: new actual Qt consumer suite: 8 passed; retained estimate/navigation suite:
6 passed. Strict qmllint passes (existing unrelated unused-import info remains).
TypeScript and daemon protocol bindings regenerated. Keyboard contract updated.
The city picker uses shared PromptDialog/FormField/TextField/DropDownList composition;
no numeric font/spacing/radius overrides were added to the panel.

Stage 5:

- Native all-targets: **191 passed, zero failed, three existing environment-dependent
  tests ignored** (156 library, 34 authority, one startup integration). Strict Clippy
  passes for the library and location-authority binary.
- Full Qt consumer suite: **365 passed, zero failed, one skipped**. The dedicated
  location suite passes **13** tests, including real keyboard/mouse interaction,
  single-flight search, explicit submission, stale revision rejection, modal closure,
  owned operation-status recovery, closed-panel completion, collapsed command access,
  inspection-only Enter, no write replay and arrival/departure selection.
- Full-suite fixture reads require `QML_XHR_ALLOW_FILE_READ=1`, as already supplied
  by the Nix check. The initial standalone run without that flag had JSON parse
  failures; the corrected run is the result above.
- Strict qmllint passes (one unrelated existing unused-import informational
  diagnostic). TypeScript regeneration, daemon-boundary and generated-contract JS
  checks pass. The real native producer matches all nine existing Qt fixture files;
  the checked bar contract is regenerated and its registry/API coverage includes
  `location` and `locations`.
- Native regression fixes retain protected Home on catalog failure and preserve
  imported cities despite malformed later calendar configuration. Publications are
  serialized; forecast I/O is bounded at 15 seconds. Catalogs allow 32 cities
  including Home, keeping duplicated forecast snapshots bounded.
- Actual Qt captures found and fixed missing shared icon-name registrations. They
  also exposed a fixture sizing mistake: tests now use `PopoverGeometry`'s real
  open canvas (1040 normal / 960 minimum) and assert that every command fits.
  Arrival at Home preserves the outgoing detail tab rather than an older Home tab.
  Time & Weather explicitly enables list Enter (disabled by the calendar base owner)
  and tests that repeated Enter inspects without opening Manual or issuing writes.
- Visual evidence: `target/time-location-review/` contains 14 reproducible Qt
  captures: all three row roles and both tabs at normal/dark and minimum/light,
  plus the manual picker and the original combined Home/Current roles (superseded
  by the clarification below). Reviewed role icons,
  unchanged action composition, passive labels and left-label modal fields. These
  use synthetic acknowledged state and unavailable forecast placeholders—not live
  location/weather/provider evidence. Artifacts are ignored, not checked in.
- `python3 tests/review-panel-ui.py --base a599abb`: zero changed-line or new-wrapper
  prompts. No panel-specific numeric typography/spacing/radius exceptions added.

Reproduce the main checks:

```sh
QML_XHR_ALLOW_FILE_READ=1 direnv exec . tests/run-qml-tests.sh
direnv exec . tests/run-qmllint.sh
mkdir -p target/time-location-review
direnv exec . tests/run-qmlquality-tests.sh \
  -input tests/manual/tst_time_location_review.qml -o -,txt
nix develop ../bar-daemon --no-write-lock-file --command \
  cargo test --manifest-path ../bar-daemon/Cargo.toml --locked --all-targets
```

## Current-city clarification

Implemented after screenshot review; native commit `d12f6b1` and Shelllist
`2432629`:

- Only one populated Current entry away from Home. The native projection replaces
  that stable entry instead of appending; missing/invalid location never creates a
  blank placeholder. The client also rejects old producer placeholders.
- Home and Current coincide throughout Amsterdam's canonical timezone. Show only
  Home's house icon/name/metadata; remove the extra Current icon and accessible
  decoration. Preserve the selected tab when Current hands off to Home.
- A known manual place supplies the Current city name and can reuse the same saved
  place's forecast without new HTTP. Stale place names or another city's matching
  timezone cannot supply its weather. Independently saved cities are unchanged.
- Set current location overrides Automatic. Only an acknowledged change replaces
  Current; returning to Automatic retains the last accepted city until a fresh
  accepted fix. Existing authorization, manual persistence, acquisition fencing and
  verified-timezone-write guards are unchanged.
- Validation: **367 Qt passes / 1 existing skip**, including **15** location tests;
  native library **158 passes / 1 existing ignored**, authority **34 passes / 1
  existing ignored**. Strict qmllint and library/authority Clippy pass. UI override
  review against `3aac074` reports zero prompts. Re-rendered the actual Qt capture
  fixture and reviewed `target/time-location-review/at-home.png`: Home only, no
  Current row or decoration. These remain synthetic, not live provider evidence.
- Read-only, non-auto-starting probes of the installed authority's `GetControl`
  and `GetAccepted` returned **Access denied**. This is a separate live-access
  blocker, not permission to fabricate a current city or bypass authorization.
  No service, system policy or timezone was changed during this correction.

## Single-control city picker

The subsequent screenshot correction replaces separate search and City fields with
one shared `SearchChoiceField` inside `SearchChoiceDialog`:

- Type to request filtered native candidates, Down/Up to highlight, Enter or click
  to choose locally. Only the separate Confirm command submits Add/Manual.
- Left/Right, Home/End, text selection and IME composition stay with the native
  editor. Escape closes suggestions first, then cancels the modal. Tab/Shift+Tab
  traverse one editor and modal commands; the dropdown arrow is not another stop.
- New results clear stale highlighting. Native request generation/revision checks,
  no-write-on-typing, captured submission identity and no-replay guards are unchanged.
- Add uses the plus identity icon; Manual uses the target. Cancel sits immediately
  left of Confirm in the shared inline header. No “Add · Cancel” footer remains.
- Ordinary and searchable dropdowns use the same extracted `ChoicePopup` and
  `DropDownOptionDelegate`. The shared UI maintainer owns the unchanged 12px popup
  radius copied from `DropDownList`; this is not a panel-local style override.
- Validation: **372 Qt passed, zero failed, one existing renderer skip**, including
  **20** Time/Weather checks. Strict qmllint passes with the same unrelated
  unused-import informational diagnostic. Actual pointer/keys cover asynchronous
  search results, popup Escape, selection versus submission, stale highlights,
  long-list scrolling, single-editor Tab traversal and modal command geometry.
  The shared popup fits above/below the editor within window margins and reveals
  the highlighted result after model/layout updates, without covering the query.
- Re-rendered `target/time-location-review/add-picker-*.png` and `add-choices-*.png`
  at normal/dark, minimum/light and the real 453px collapsed chooser width. Reviewed
  full editor-column fit, the suggestion list, icon and aligned command buttons.
  These are Qt renders of recording fixtures, not live geocoder/system tests.
  No hardware IME or human screen-reader validation was performed.

## Deployment acceptance still required

No service was installed/restarted and no live system timezone was changed. Local
source builds/tests are not proof of installed system-bus/polkit authorization or
real provider availability. Deploy matching Shelllist/session-daemon/authority
packages and policies using the repository's current-source co-development workflow;
there are no new private dependency pins. Then explicitly authorize a live smoke
check: add/search/remove, manual timezone/readback, restart persistence, Automatic
resume, travel home/away and interrupted-connection recovery. Confirm the real
geocoder and automatic acquisition provider, and verify that an inactive/remote
caller is rejected. Never remove the uncertain-write or administrative override
fences to make that smoke check succeed.

Pre-existing sibling `docs/location-timezone.md` and `flake.nix` edits remain
uncommitted and untouched by these stage commits.
