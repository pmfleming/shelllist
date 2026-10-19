# Time & Weather location implementation

Approved design: [revision 3 HTML plan](time-panel-location-plan.html).

## Commit stages

1. Contract and execution record — complete (this commit).
2. Native saved-city catalog, fixed Amsterdam Home and at-home projection — complete, bar-daemon `aa65230`.
3. Authorized manual/automatic location authority controls and session API — complete, bar-daemon `376dba0`.
4. Shared panel icon commands, picker and confirmation — complete (this commit).
5. Integration fixtures, broader native/Qt tests and documentation — next.

Each completed implementation stage is committed in its owning repository.
Completion and validation are recorded below; a planned stage is not a claim of
implemented or tested functionality. Services are not activated by this work.

## Contract

- Home is protected Amsterdam, Europe/Amsterdam. Its fixed place/weather data
  never becomes the current estimated coordinates.
- Home has a passive house icon; Current has a target. At home the Amsterdam row
  has both roles and no separate Current row. Compare canonical timezone identity,
  not current UTC offsets; unknown location is not proof of being home.
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
