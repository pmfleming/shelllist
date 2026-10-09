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

Implementation and engineering acceptance complete. Evidence is deliberately
split by boundary; this is **not** a blanket hardware/accessibility certification.

- Strict qmllint: **pass**. Full combined working-tree Qt suite: **339 passes,
  zero failures, one existing software-renderer artwork skip**. All **17
  JavaScript suites** pass (including 150 seed/mode contrast combinations and
  source-tree import checks); native offscreen runtime smoke passes. A separate
  archive of HEAD plus **only this phase's owned paths** also passes strict lint
  and the full suite: **320 passes, zero failures, one existing skip**. This rules
  out relying on unrelated unstaged implementations to make the commits pass.
- Normal light/dark panel fixtures: **28 passes / 110 images**, including
  auxiliaries, subpages, 976×600 resources, long failures and pending policy.
  Dense/read-only/invalid/narrow forms: **4 passes / 10 images**. Display layout,
  drag, mirror/disabled monitors, Focus, minimum/overflow, dirty and timed-trial
  states: **4 passes / 42 images**, with initial Revert focus asserted.
- Fractional offscreen scale 1.25×: **28 passes / 110 images**. Live Wayland on
  the existing 3440×1440 monitor at scale 1.25, using Qt 6.11.1/OpenGL RHI:
  **28 passes / 110 images**. The latter uses real Wayland windows but recording
  transports, not real daemon mutations or physical mode switches. QRhi pipeline
  output and monitor geometry are in the separate `wayland.log` and monitor JSON.
- Visual inspection included both themes, full-size switches, measured Resources,
  Activity with long native-projected events/todos, field/state feedback, long
  Wi-Fi and notification errors, passive Tray, expressive Time/Weather, and
  Display Keep/Revert. Loaded Activity exposed a real clipped-row risk: event
  rows now size from all text, long todo rows grow without shrinking their switch,
  and delete commands retain secondary size. Search prompts use sentence case.
- Tests wait for the Activity asynchronous Loader to become Ready before layout
  and pointer input, rather than assuming finding a child means it is ready.
  Capture helpers verify asynchronous image writes; bar snapshot fixtures are
  acknowledged so ready Audio/Media captures no longer show false busy controls.
- Canonical local comparison gallery: `target/panel-standardization/phase4/gallery.html`.
  Rebuild with `python3 tests/build-panel-gallery.py`; its image/document links
  are checked. Headless Chrome confirms twelve comparisons, named enlargement
  links, light-theme disclosure and no horizontal overflow at 1440px or 390px.
  Images remain ignored evidence, not shipped assets or pixel goldens.
- `AGENTS.md`, this matrix and the keyboard contract now describe current roles.
  `tests/review-panel-ui.py --base <ref>` identifies added numeric role overrides,
  shared composition changes and new local setting wrappers for explicit review.
  Reviewing against phase 0 found shared-composition migrations, not a new family
  of local setting wrappers. Domain geometry is intentionally not blanket-banned.
  The Python review detector's changed-line numbering and numeric/composition
  classification were smoke-tested; generated gallery references all resolve.

**Evidence limits / owner follow-up:** the existing artwork pixel skip stays a
skip even though separate RHI captures were inspected. Native accessibility
names/state/activation and keyboard transactions are exercised by Qt tests;
no hardware IME session or human screen-reader walkthrough was performed.
The desktop/QA owner retains those checks, real native-menu integration,
compositor blur/input masks and physical display-mode recovery. No destructive
or hardware-mutating acceptance was attempted. Incoming resource, notification
and choice-session work remains separate; these counts validate the combined
checkout, not a claim that those unrelated changes were authored by this plan.

## Panel acceptance matrix

Every row has normal/minimum light/dark captures, plus a separate fractional and
live Wayland pass. Additional state/transaction evidence remains at the consumer
boundary instead of being duplicated in a giant visual test.

| Panel | Representative captures / states | Native regression owners (`tests/qml/`) |
| --- | --- | --- |
| Applications | Application, Settings, measured Resources, missing network data, minimum viewport | `tst_application_details`, `tst_application_settings`, `tst_application_resources`, `tst_application_actions` |
| Wi-Fi | IPv4/IPv6, long errors, narrow/required/read-only/invalid fields | `tst_ip_fields`, `tst_wifi_operations`, `tst_wifi_prompt`, `tst_wifi_portal` |
| Bluetooth | Device, Settings, Information, adapter General/Pairing, unavailable controls | `tst_bluetooth_recovery` |
| Clipboard | Data/Information, long text, loading with retained content | `tst_clipboard_preview`, `tst_clipboard_recovery` |
| Displays | Layout/Information, Focus subpages, draft/trial, drag, mirror/disabled, narrow/short | `tst_displays` |
| Battery & Power | Overview/Care/Power, unavailable telemetry, long failure, firmware controls | `tst_battery_presentation`, `tst_battery_suspend` |
| Activity | Glance/Schedule, long event/todo, empty day, error with retained content | `tst_activity_days` |
| Notifications | Previews/Controls/global settings, pending/error, singular count | `tst_notification_center`, `tst_notifications` |
| Time & Weather | Time/Weather, solar/timezone, unknown forecasts, measured hero | `tst_time_weather_locations` |
| Audio | Output, ready commands, mute, long failure | `tst_system_choosers` (includes input/target guards) |
| Media | Ready transport, pin/mode, long failure, passive metadata/artwork | `tst_system_choosers` |
| Tray | Passive details without duplicate card, stable native-menu routes | `tst_system_choosers` |

Shared `tst_panel_roles`, `tst_field_interaction`, `tst_material_feedback` and
chooser/command suites cover identity, wrapping, passive roles, browse/edit
markers, editable-only traversal, Enter/Tab save, Escape discard, snapshot/draft
isolation, continuous-preview rollback and guarded command activation.

## Maintainer review / owned exceptions

The frontend maintainer owns the shared roles; each panel's domain maintainer
owns its deliberate content geometry. Desktop/QA owns hardware/live acceptance.

| Exception | Owner / reason |
| --- | --- |
| Weather/time/media heroes, artwork | Time/Weather and Media maintainers; semantic prominence and domain imagery, named size roles |
| Resource card geometry, 14px essential-value floor, 11px plot annotations | Applications maintainer; viewport fit, metric semantics/gaps, no extra chart interaction |
| Calendar cells, agenda markers, monitor maps, notification content | Respective domain maintainers; content geometry is not a settings heading or field |
| Stacked FormField name on a narrow compound todo editor | Shared UI + Activity maintainers; keep name and native input usable without reducing text/control size |
| Read-only/unsupported controls and pending state | Domain maintainer; preserve availability/retry/acknowledgement, never imply success or an editable value |
| Bar, toast, prompt, OSD and native menus | Shell/desktop maintainers; independent density, routing and safety boundaries |

For every panel PR:

1. Use semantic Theme roles and shared fields/headings/status; explain new numeric
   font, spacing or corner overrides and local wrappers in review.
2. Keep exactly one identity header. Omit empty or duplicate card headings; make
   routine guidance explicit Help, not a key legend. Keep actionable blockers,
   countdowns and failures visible and wrapping.
3. Check long labels, pending/error/disabled/read-only and minimum supported size
   in both themes. Preserve switch geometry and readable passive metadata.
4. Preserve native editor identity, accessibility name/description, command ID,
   draft/save/rollback and domain acknowledgements. Help/status/artwork add no
   field stops. Test the affected actual consumer, not just a token table.
5. Refresh the small representative gallery/matrix; record renderer, font setup,
   fixture limitations, skipped cases and any unperformed hardware checks.

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
