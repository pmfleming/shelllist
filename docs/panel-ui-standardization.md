# Panel UI standardization

Approved implementation of the illustrated panel plan (`shelllist-panel-ui-standardization.html`
in the parent Projects directory). This is the current visual-role specification;
historical proposals are not additional requirements. The
[interaction contract](chooser-keyboard-workflow.md) remains authoritative.

## Approved roles

| Role | Standard |
| --- | --- |
| Identity | 20px bold, 12px regular subtitle; elide with accessible full name |
| Group/card heading | 16px medium, sentence case; optional, no empty heading gap |
| Field name | 14px medium, muted; wrap rather than shrink |
| Text/dropdown value | 16px regular; segmented options retain native option styling |
| Body/error/status | 13px, wrapping; pending is not acknowledged success |
| Metadata | 12px; 11px only for nonessential chart ticks/annotations |
| Form/setting row | 52px minimum compact form; ordinary settings/toggles 56px |
| Switch | 52×32 track, 16/24px off/on thumb; compact does not shrink the switch |
| Inspector inset | Symmetric 16px at 1×; shared outer geometry remains unchanged |
| Card spacing/padding | 12px peers/padding; 24px only for a distinct major group |
| Standard card | 16px radius, opaque tonal surface, no nested outline |
| Commands | Existing 56/28 primary, 32/16 expanded secondary, shared responsive floor |

Semantic roles reuse existing Theme values. Do not change all occurrences of a
size token merely to fix one role. Shared passive compositions must not become
editable stops or request owners. Read-only telemetry is not a disabled field.
Known values and labels remain readable when controls are unavailable.

Routine guidance belongs in explicit Help and native descriptions, not persistent
key legends or hover tooltips. Failures, blockers, pending operations, countdowns,
dirty display layouts and safety consequences remain visible. Keep independent
error/retry ownership; presentation components never dispatch domain mutations.

## Intentional exceptions

- Weather/time/media heroes retain expressive artwork and larger named reading
  sizes. Hero frames may retain 20px corners; ordinary surrounding cards use 16px.
- Resource microcards retain their 2×2 plus full-width, viewport-fitted layout,
  metric colors/units, missing-data gaps and single editable range selector.
  Preserve the no-new-help/no-chart-keyboard contract. Prefer reducing chart
  ornament over shrinking essential values; essential readings have a 14px
  minimum, while chart ticks may remain 11px. Verify short-height fit separately.
- Calendars, monitor maps, notification previews and charts retain domain content
  geometry. Notification content titles are not structural group headings.
- Battery's title/percentage is a heading-only header, not an invented chooser
  primary action. Its circular power selector remains one deferred field.
- The top bar, native tray menus, OSD, required-input dialogs and toasts retain
  their own documented density and input boundaries. Panel roles must not
  unconditionally restyle those contexts.

## Execution and evidence

Each phase is a separate commit. Local, non-mutating captures and logs are under
`target/panel-standardization/phaseN/`; generated images are not goldens or shipped
assets. Input worktree/index/patches were captured under `baseline/` before edits.
Existing staged documentation removals and unrelated in-progress work are not
part of these commits.

### Phase 0 — baseline and decisions

- Accepted the roles/exception decisions above; no interaction redesign.
- Baseline Qt suite: **332 passes, zero failures, one existing renderer skip**.
  Counts include lifecycle hooks, not independent coverage units.
- Updated the existing all-panel capture fixture to current native notification
  catalog and time/weather location projections. Removed a stale circle assertion
  on bar-specific artwork; retained actual panel circle assertions.
- Added subpage captures for Applications, Bluetooth (device + adapter), Clipboard,
  Displays, Notifications, Time/Weather and all Battery pages. Existing separate
  form and display fixtures cover dense IP fields and global Focus subpages.
- Updated capture fixture: **28 passes, zero failures**; form fixture: **4 passes**.
- Inspected representative baseline Resources, Battery Care, Time and Notifications
  images. Resource loading/unknown examples alone do not prove measured-value fit;
  loaded resource/short-height cases are required before final acceptance.

### Phase 1 — shared roles

- Added semantic Theme roles, shared `SectionHeading` (optional explicit Help),
  wrapping `InlineStatus` and `PanelMessage`; no domain state/request ownership.
- Standard cards/sections use the shared heading. Field, setting and slider label
  roles agree; compact switches retain 52×32 geometry and do not fade labels.
- Inspector defaults are symmetric; pending SaveStatus no longer uses success color.
- Added native shared-role tests for long labels, disabled activation, Help commands,
  editable-only traversal, Escape discard and wrapping/error-message sizing.
- Strict lint and the form capture fixture pass. Full suite at this checkpoint:
  **338 passes, zero failures, one existing renderer skip** (including lifecycle).
  A pre-existing incoming Bluetooth test exhibited asynchronous page-entry timing;
  an isolated readiness experiment was reverted to avoid committing another
  in-progress change. Final acceptance reruns the complete combined working tree.
- Existing TimeWeather location-fixture `undefined` boolean warnings were present
  in the phase-0 baseline; they are not newly introduced QML role failures.

### Phase 2 — pilot forms

- Wi-Fi uses shared inspector insets, sentence-case tabs, field-label roles and
  content-sized diagnostics. The wrapping advanced error panel reserves space
  instead of covering controls. Native IP/DNS validation/credentials are unchanged.
- Bluetooth removes its title-size override, uses consistent search/login labels,
  retains readable codec information with disconnected context, and discloses
  routine policy guidance from the shared card heading. Native identities,
  profile/adapter saves and recovery are unchanged.
- Battery's heading-with-Help is now a compatibility wrapper around the shared
  component, retaining its command identity. Headings/validation are aligned;
  sleep commands use SurfaceActionRow with their original IDs/chords/guards.
  Keep awake retains its native checkable action and independent state.
- Strict lint: pass. Full combined Qt suite: **338 passes, zero failures, one
  existing renderer skip**, without the temporary readiness experiment.
  All-panel captures: **28 passes**; dense-form captures: **4 passes**.
- Inspected Battery Care/Power, Bluetooth adapter General and narrow IPv6 captures.
  Short/narrow forms scroll and wrap rather than shrinking switch geometry.
  Recording transports confirm no mutations during capture.

### Phase 3 — remaining panels

- Applications/Clipboard use symmetric insets; Applications drops redundant
  resource guidance, Clipboard uses “Information” and readable file metadata.
- Displays uses a labeled Content form with the existing mirror selector; routine
  docking guidance is explicit Help, while consequences, pending/dirty blockers,
  layout validation and the guarded trial workflow stay visible and unchanged.
- Activity has one identity and Schedule context, Calendar/Agenda/Todos group
  headings and tonal cards. Its narrow compound todo editor opts into a shared
  stacked field label rather than squeezing the input behind its label.
- Notifications uses the shared inset/status roles and correctly singular counts.
  Its native catalog, notification previews and policy/error ownership are intact.
- Time/Weather retains expressive heroes with named size exceptions; surrounding
  headings are sentence case, forecast cards share roles, location-list metadata
  is at least 12px and the Home marker has a named accessible glyph.
- Audio uses the shared command row without changing action IDs; Media's Bar
  controls selector is a named form; Tray removes a card repeating its subtitle.
  Playback artwork, capability guards and native tray menus remain unchanged.
- Shared list status wraps at 13px instead of truncating operation feedback.
  Resource readings cannot shrink below 14px; chart layout/series/requests are not
  redesigned or included from the separate in-progress resource work.
- Capture fixtures now include genuinely measured resource snapshots/history at
  976×600, not only loading placeholders. Display fixtures supply the required
  native baseline token; omission had correctly disabled draft/drag controls.
- Reviewed normal/minimum Resources, Activity Schedule, Audio/Media and Time
  captures. Added shared native-field identity/stacked-label/readability tests.
- Strict lint and full suite pass (**339 passes, zero failures, one existing
  renderer skip**). Captures: **28 passes**; forms: **4**; display workflow: **4**.

### Phase 4 — acceptance and prevention

Pending. Offscreen evidence does not establish hardware IME, assistive-reader,
compositor blur/input-mask or live display-mode safety acceptance. Record these
limits explicitly, never convert a renderer skip into passing pixel coverage.

## Reproduction

Use the repository development shell (`direnv exec .` or `nix develop`) with
matching Qt plugins and a Fontconfig file containing packaged Roboto Flex,
Material Symbols Rounded, JetBrainsMono Nerd Font and Noto fallback. The manual
fixture outputs require the directories described in `tests/manual/README.md`.

```sh
tests/run-qmllint.sh
tests/run-qml-tests.sh
tests/run-qmlquality-tests.sh -input tests/manual/tst_action_review.qml -o -,txt
tests/run-qmlquality-tests.sh -input tests/manual/tst_form_review.qml -o -,txt
tests/run-qmlquality-tests.sh -input tests/manual/tst_display_review.qml -o -,txt
```

Review all twelve surfaces in light/dark, normal/minimum geometry, long labels,
read-only/blocked/busy and error states. Confirm editable-only traversal,
Enter/Tab save, Escape discard, bound-value restoration, modal guards and
acknowledgement/recovery at the actual consumer boundary.
