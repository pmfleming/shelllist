# Shelllist circular actions: audit, plan and implementation

Status: implemented. The pre-change audit and agreed migration sequence are
retained below for traceability; they are not descriptions of the current UI.

## Delivery

- Shared `DetailsHeader`/`SurfaceActionRow` now align the primary circle with the
  title and identity icon, with a separate right-aligned secondary row. Titles
  and subtitles elide after reserving the primary and a 16px gap. Secondary
  overflow fits independently and retains the existing popup/key model.
- Commands have fixed circular geometry and no rendered labels, including press
  states. Header primary/secondary diameters are 56/48px and icons are 28/24px.
  Existing semantic colours and disabled guards remain. Wi-Fi no longer applies
  viewport-dependent header scaling; per-panel header height variants are gone.
- All 12 surfaces are migrated or inherit the shared header. Activity uses the
  shared header and schedule buttons. Notifications moves one command group
  between the collapsed-result host and expanded message header; shared command
  discovery deduplicates objects and excludes command groups from field readiness
  and Tab traversal. Closed notifications do not acquire a default action.
- `LabeledAction` supplies passive explanations beside circular settings/retry
  commands. Application-defined desktop actions use named passive rows with a
  recognised icon or execute fallback; arbitrary icon-name text is never painted
  as a glyph. Notification app actions use a named menu.
- Modal headers use the same hierarchy and preserve contained native traversal,
  required inputs, accept guards and safe initial focus. Displays retains Revert
  focus and explicit Preview/Keep/Revert boundaries. Toast headers and compact
  bar controls are circular; the bar clock is passive text beside its command.
- Material symbol names are explicitly mapped and identity tiles use the same
  glyph resolver. No backend protocol, operation or field transaction changed.

Validation and live-acceptance limitations are recorded at the end.

## Owner requirements

Apply consistently across Shelllist:

- A panel's primary action is right-aligned in the expanded title/icon band,
  not in a separate row underneath it.
- Secondary actions form a right-aligned row below the primary action. The
  right edge of the final secondary aligns with the primary's right edge.
- Titles elide before the actions, with a real layout gap after the ellipsis.
- Every command button is an icon-only Material 3 circle. No visible button text.
- The primary has a larger circle, larger icon and distinct filled colour.
- Preserve danger/warning meaning, disabled states and all domain safety guards.

Target arrangement (secondary actions are a horizontal row, not a vertical list):

```text
[identity icon]  Long expanded title…       [ LARGE PRIMARY ]
                Status / subtitle…
                                  [secondary] [secondary]
---------------------------------------------------------
                         detail content
```

The primary and identity icon are centred on the title band; subtitle/status is
supporting content, not a reason to push the primary into the secondary row.
The title's available width excludes the primary footprint and a fixed gap.
The secondary row cannot collide with supporting text or the content below it.

## Scope and unchanged behaviour

The audit covers all 12 IDs in `shell/SurfaceRegistry.qml`, their detail pages,
settings/recovery commands, and shared dialogs, list actions and bar/toast actions.
It is a source audit plus review of the supplied Wi-Fi and Clipboard screenshots,
not a live visual acceptance run of every panel.

The **button treatment** applies everywhere. The **title/primary/secondary
arrangement** applies to panel headers and command-bearing section/card headers;
field-local actions stay associated with their field, rather than being moved to
the panel's top-level action group. Give those local groups the same right-aligned
hierarchy where a primary exists. Do not invent a primary for information-only
or settings-only pages.

Text fields, switches, segmented options, dropdown options, calendar date cells,
workspace selectors and menu entries are not command buttons to be stripped of
their value/selection text. A labelled clickable status capsule must not become
an accidental exception: separate its passive status text from its circular
command affordance. Menu entries retain meaningful names and conventional menu
navigation; their launcher is a circular icon button.

Full action labels remain as accessible names and command-menu names. Where an
icon is ambiguous, retain passive explanatory text outside the button. Do not
introduce hover tooltips or permanently printed shortcut letters inside buttons.
Existing modifier-held shortcut badges remain separate overlays.

The mandatory [keyboard contract](../chooser-keyboard-workflow.md) remains:

- shared `ProviderChooserSurface` / `PanelSurface` navigation;
- actions excluded from ordinary field Tab traversal, activated with Alt+letter;
- existing Enter/result actions, Alt+M overflow and Alt+J content menus;
- field-local save/discard, daemon acknowledgement, capability and retry guards;
- required-input modals retain their documented native contained Tab exception.

This plan supersedes the **visual target** in
[`surface-action-row.md`](surface-action-row.md): the labelled primary, one row
below identity, label-width sizing and pressed capsule treatment are not the new
target. Its command routing, overflow safety and accessibility work is retained.
The old document's delivery/test results describe that earlier implementation.

## Pre-change shared implementation findings

| File | Current implementation | Required change |
| --- | --- | --- |
| `qml/Shelllist/Ui/DetailsHeader.qml` | A `Column`: identity/title/status first, `SurfaceActionRow` underneath. | Shared two-tier header composition with the primary in the identity band and secondary row below. Preserve icon/image/signal variants. |
| `qml/Shelllist/Ui/SurfaceActionRow.qml` | One right-aligned `Row`, primary first; `iconOnly: false` on primary. Secondary fitting reserves the labelled primary's width. | Separate primary and secondary placement without duplicating commands. Fit overflow against the secondary row's own width. Remove label-driven widths. |
| `qml/Shelllist/Ui/ActionButton.qml` | Icon-only only when an icon exists; callers can stretch it. Press morphs the circle/capsule to an 8px corner. | Shared circular command variant with square visual bounds, explicit icons and accessible labels; keep circular shape on press and use M3 colour/state feedback. Migrate all command consumers before eliminating legacy text styling. |
| `qml/Shelllist/Ui/FlatIconButton.qml`, `DestructiveIconButton.qml` | Inherit button paint but caller-owned dimensions and tone overrides vary. | Route through the same circular primitive with standard/filled/tonal/error variants. |
| `qml/Shelllist/Ui/Theme.qml` | Primary 48px, secondary 38px; both header icons use the 15px small token. Primary widths 112–260px. | Diameter/icon/gap tokens instead of text width tokens; primary icon must actually be larger. |
| `qml/Shelllist/Ui/ResultLabel.qml` | Title/subtitle already elide, but currently get the entire identity row. | Constrain header text after reserving action space; allow it to shrink. Keep ordinary result-row geometry unchanged. |
| `qml/Shelllist/Ui/ActionToolbar.qml` | Supports text fallbacks, `fillActions` and `showLabels`, so icon buttons can still become pills. | Circular command layout; flexible spacer takes extra width, never the button. Audit modal callers separately from detail commands. |
| `qml/Shelllist/Ui/DetailsNavigation.qml`, `ShortcutHints.qml` | Discover `SurfaceActionRow` buttons; exclude `DetailsHeader` from ordinary command/field recursion. | Preserve typed discovery, live delegate tracking, popup ownership and badges through the structural change. Moving buttons must not lose commands or register them twice. |
| `qml/Shelllist/Ui/ActionDetailsPane.qml` | Body height subtracts the current header height. | Use the new natural header height; retain scrollable body and existing margins. |

Agreed and delivered logical-pixel tokens: **56px primary / 28px icon**, **48px
secondary / 24px icon**, **8px button gap**, **16px text-to-action gap**. These
are shared implementation tokens, not dimensions inferred from the screenshots.
Compact bar/list contexts can use a shared smaller circular variant with usable
hit targets; do not scale every panel down to fit. Validate tokens at the existing
supported geometry before finalising them.

Use M3 primary/on-primary for the main action and a neutral tonal or outlined
secondary treatment. Destructive/warning actions retain semantic paired colours;
do not turn Disconnect, Forget or other guarded actions into ordinary blue
commands solely to satisfy primary emphasis. Focus and disabled paint must remain
legible in both themes. The circle's radius remains half its diameter in every
interaction state; hit geometry never animates.

## Pre-change panel-by-panel audit

Paths below are relative to the repository root.

| Panel | Current header and actions | Planned migration and safety boundaries |
| --- | --- | --- |
| Applications | `launcher/ApplicationDetails.qml` uses `ActionDetailsPane`: Launch/Focus primary, New tile and Close secondary. `ApplicationDesktopActions.qml` stretches arbitrary desktop actions; `ApplicationInstanceList.qml` has contextual focus/close buttons. | Inherit shared header. Convert desktop/window commands to circles without guessing arbitrary action semantics: keep supplied meaningful icons, otherwise expose named entries through the content menu or passive-labelled action rows. Preserve launch/focus/close routing and in-flight guards. |
| Wi-Fi | `wifi/NetworkDetailsPane.qml` uses shared header: Connect/Disconnect/Cancel, then Forget/Sign in/Share. This is the first supplied screenshot. Credential and QR dialogs use stretched/text `ActionToolbar`s. | Shared title-aligned primary and lower secondary row; retain long SSID/status elision and danger tones. Convert dialog buttons too. Sign in remains Alt+I with daemon intent/claim acknowledgement; no field navigation may launch it. Preserve credentials, confirmation and connection guards. |
| Bluetooth | `bluetooth/BluetoothDeviceDetails.qml` uses shared header: Pair/Connect/Disconnect, Reset/Forget. Adapter context has no header action group. `BluetoothDeviceActions.qml`, `BluetoothAdapterSettings.qml`, `BluetoothDeviceAudio.qml` contain text restore/retry/discard/default-input/output buttons. | Inherit header; convert all contextual commands with explicit icons and passive status text. No artificial adapter primary. Preserve pairing prompts, rename draft/retry ownership, daemon acknowledgement and audio availability guards. |
| Clipboard | `clipboard/ClipboardDetails.qml` uses shared header: Paste, or Copy for binary; Copy/Paste as file/Edit-or-Open secondaries. `ClipboardDetailCards.qml` has text retry/discard; `ClipboardListPane.qml` has a wide text history-retry button. | Inherit header; preserve conditional binary/link actions and unique keys. Convert retry controls, placing error text outside them. Preserve edit leases, failed drafts and destructive/external-open confirmations. The screenshot's raw PNG-like title is a separate title-generation issue: record it, but do not conflate data decoding with this layout migration. |
| Displays | `displays/DisplayDetails.qml` uses shared header: Preview, Identify, Enable/Disable; global settings has no actions. `DisplayArrangementControls.qml` has four stretched text buttons; `DisplayFocusPane.qml` has text restore; `DisplayTrialDialog.qml` forces text Keep/Revert. | Inherit header; circular directional icons with existing Alt+L/U/D/R, plus restore/Keep/Revert icons and passive explanations/countdown. Preserve local layout drafts, explicit Preview boundary, trial timeout/revert, topology invalidation and confirmation guards. Back/undo/help controls share the circular style. |
| Audio | `bar/SystemChooserContent.qml` uses `ActionDetailsPane`; Mixer is secondary, no primary. Volume decrement/increment is a local `ActionToolbar`; mute is a setting. | Keep a secondary-only header, no invented primary. Standardise local +/- circles. Keep mute as a switch and existing volume/domain behaviour. |
| Media | Same shared inspector: Play/Pause primary; Previous/Next/Rewind/Forward secondaries. A full-width text Resume automatic player selection action appears in preferences. | Inherit header; convert preference command with external state explanation. Preserve capability-based playback/seek guards, player pinning and automatic selection. Result Enter still inspects rather than silently becoming playback. |
| Tray | Same shared inspector: Activate primary; Menu, Secondary activation and scroll commands secondary. Native tray menu has separate lifetime/focus handling. | Inherit header; retain native menu ownership, timeout, generation/deactivation guards and focus restoration. Result Enter still inspects. |
| Activity | `activity/ActivityContent.qml` has a standalone title followed by `SurfaceActionRow`: Today primary on overview; Overview/Refresh secondaries. Schedule uses custom text `ActivityHeaderButton.qml` for previous/next/Today. Todo has local add/delete icons. | Replace standalone header layout with shared composition, including an identity icon. Keep Today primary only where already meaningful; do not promote Refresh when Today disappears. Replace bespoke schedule buttons with shared circular controls. Preserve dates, section navigation, todo editing and existing command routes. |
| Time & Weather | `activity/TimeWeatherDetails.qml` uses `ActionDetailsPane` with city identity and no header commands. Time/Weather selectors and weather location cards are navigation/selection controls. | Inherit constrained title layout without empty action rows or an invented primary. Preserve location selection, time/weather tab navigation and content cards. No gratuitous conversion of information/selection cards into command circles. |
| Battery & Power | `battery/BatteryContent.qml` has a custom title/percentage header, no global commands. Power has circular keep-awake/lock/suspend/hibernate controls; protection, levels and suspend-policy panes have full-width text commands. | Keep percentage as information, not a primary button. Convert charge-once, pause/resume, calibration/cancel, automatic-profile resume, critical-hibernation cancel and retry controls. Use shared local command groups, keeping explanations/status outside buttons. Preserve capability/inhibition/calibration guards, countdown cancellation semantics, preview sliders and pointer-only chart inspection. |
| Notifications | `activity/NotificationContent.qml` uses a custom detail flickable. `NotificationHistoryRow.qml` has no shared header; `NotificationCommands.qml` puts selected-message actions under the search/list, left-aligned. Settings has text DND retry/dismiss-all buttons. | Add shared message identity/action header when expanded: live default Open is primary only when available, remaining message commands below/right. Retain collapsed-result commands through `additionalCommandItem`/`commandsWithoutDetails`; use one live command source, never duplicate Alt registrations. Convert settings commands and reply Send to shared circles. Closed messages must not acquire live actions; reply draft/sending and default-action semantics remain intact. |

### Additional Shelllist-wide consumers

- **Prompts and confirmations:** `Ui/PromptDialog.qml`, `ConfirmationDialog.qml`,
  `ModalFrame.qml`, Wi-Fi credential/QR dialogs, Bluetooth pairing, Clipboard
  prompts and Displays trial dialog. Introduce shared circular modal command
  placement rather than leaving text-button exceptions. State the operation and
  consequences in passive dialog text; retain accessible action names, initial
  focus, explicit submit/cancel, conventional modal Tab and all safety guards.
  Do not use an unexplained generic checkmark for a destructive operation.
- **Notification toasts:** `bar/NotificationToastCard.qml`,
  `Ui/NotificationQuickActions.qml`, `NotificationActionList.qml` and
  `NotificationReplyRow.qml`. Normalise quick/send buttons and replace arbitrary
  labelled action pills with a circular named-actions menu launcher where icons
  are unavailable. Preserve reply drafts, default activation, expiry, swipe
  dismissal and grouping. Use the same title/action separation where a primary
  command is displayed; no toast-local geometry variant.
- **Chooser/list/search chrome:** `Ui/ChooserHeader.qml`, `ResultRow.qml`,
  `TextField.qml`, launcher/clipboard row actions. Check every action is square,
  icon-only and circular, with no hit-target overlap or clipped shortcut badges.
  Do not alter list selection, search editing or password-reveal semantics.
- **Bar:** `bar/BarAction.qml`, `BarContent.qml`, `MediaChip.qml`,
  `MediaControls.qml`, `BarTray.qml` and `BarTrayItem.qml`. Audit symbolic actions
  against the shared circle style; extract passive track/clock/status text from
  labelled action capsules where necessary. Retain right/middle click and wheel
  routes. Bar transport remains a compact toolbar, not an expanded panel header;
  its Play/Pause hierarchy should use the shared compact primary variant.
  Workspace selection is not a command-button relabelling exercise.
- **OSD and identification overlays:** `bar/BarOsdContent.qml` and
  `displays/DisplayIdentifyOverlay.qml` are feedback surfaces, not reasons to add
  actions. Check shared-control fallout; retain their informational behaviour.

## Agreed implementation sequence (completed)

### 1. Shared circular button and header foundation

1. Add theme tokens and a shared circular command presentation using
   `ActionControl`/`ActionButton`, not a new activation/navigation implementation.
2. Refactor `DetailsHeader` and `SurfaceActionRow` together. Keep one command
   owner exposing primary, secondary, overflow and live button references to
   `DetailsNavigation`. Do not create independently active duplicate delegates.
3. Reserve the primary diameter plus text gap before laying out the title;
   align icon/title/primary in the upper band. Lay out secondaries below with a
   shared right edge, then calculate natural header/body height.
4. Overflow trailing secondaries to More when necessary. Keep circles at their
   target size, reserve More's footprint, and never wrap into the title or
   shrink the primary. No-primary/no-secondary/disabled/hidden transitions must
   have explicit geometry, with no empty button placeholders or accidental
   focus resets. Preserve Activity's stable content position where possible.
5. Update shared Qt interaction/layout tests in the same change. Existing tests
   that force overflow using the old labelled-primary width need new fixtures.

### 2. Shared-header panels and screenshot acceptance

Migrate Applications, Wi-Fi, Bluetooth, Clipboard, Displays, Audio, Media, Tray
and Time & Weather through the shared foundation. Verify action descriptor icons,
keys, semantic colours and availability; avoid per-panel positioning overrides.
Capture Wi-Fi and Clipboard first to compare directly with the supplied examples.

### 3. Custom headers and contextual commands

Migrate Activity and Notifications to shared header geometry; audit Battery's
information header and local groups. Convert all text/stretch command consumers
listed above. Keep settings controls and field-local command scope intact.
Arbitrary application/notification actions need named menu entries or passive
labelled rows, not several indistinguishable fallback-icon buttons.

### 4. Dialogs, toasts, bar and remaining shared consumers

Remove remaining command text/pill fallbacks after assigning icons and preserving
external explanations. Check compact variants rather than making bar controls as
large as expanded-panel controls. Exercise destructive and required-input dialogs
before removing the legacy button styling path.

### 5. Documentation and acceptance

Update `docs/material-visual-foundation.md`, `docs/chooser-keyboard-workflow.md`
(command presentation/accessibility, not a new key model), and the old
`surface-action-row.md` status to describe the delivered contract. Update geometry
documentation if natural header heights or the tested minimum envelope change.
Do not leave the historical labelled-primary rule presented as the current target.

## Test and review plan

Add/update actual Qt tests, not only descriptor assertions:

- `tests/qml/tst_surface_actions.qml`: primary/identity vertical alignment,
  shared right edges, true square circles, larger primary icon, no rendered
  button labels, title/subtitle elision with measurable gap, overflow and
  primary-only/secondary-only/no-action states. Include long translated titles,
  icons/images, disabled actions, live action changes and scale/width cases.
- `tst_action_control.qml` / `tst_material_feedback.qml`: circular shape through
  hover/press/disabled states, accessible names, immediate focus feedback and
  non-animated hit geometry. Check light/dark semantic colour contrast.
- `tst_chooser_keyboard.qml` / `tst_field_interaction.qml`: actual Alt commands,
  250ms modifier badges, actions excluded from field Tab, unchanged editable
  transactions, duplicate keys fail closed and AltGr safety.
- Retain overflow/menu regressions: disabled skipping, resize/model-change
  closure, popup/modal blocking, activation exactly once and focus restoration.
- `tst_system_choosers.qml`, `tst_notifications.qml`,
  `tst_notification_actions.qml` and domain suites: custom header command
  discovery, expanded/collapsed notification commands, reply focus, dialog
  native traversal, tray menu ownership, display Preview/Keep/Revert and Wi-Fi
  Sign in acknowledgement. Existing recovery tests must remain green.
- `tst_chooser_geometry.qml`: header height changes do not move the anchored
  result list, overlap tabs/body, or defeat emergency scrolling/revelation.

Run in the development environment:

```sh
tests/run-qmllint.sh
tests/run-qml-tests.sh
tests/run-runtime-smoke.sh
git diff --check
```

Review captures of **all 12 panels**, including settings/error states, at normal
and minimum supported widths and fractional/HiDPI scale, light and dark themes.
Also review representative prompt, trial, toast and compact-bar states. Inspect
long SSIDs, filenames, application/track titles and city names. Live compositor
placement, hardware modifiers and screen-reader announcements remain separate
acceptance; offscreen tests cannot establish them.

Done means no visible command-button text, no stretched command circles, no
label/action collisions, and no panel-local implementation of the new header or
keyboard model. Existing domain effects, confirmation policy and field saves
must be unchanged.

## Validation record

- Strict `tests/run-qmllint.sh` and explicit lint of the manual capture fixtures:
  passed, zero warnings.
- `tests/run-qml-tests.sh`: **251 passes including lifecycle hooks, 0 failures,
  0 skipped**. Added actual Qt tests for geometry/scales/icon and image identity,
  circle states/contrast, nonvisual labels, passive contextual rows, modal native
  traversal, named notification menus and unique expanded/collapsed commands.
- `tests/run-runtime-smoke.sh`: both native offscreen configurations loaded. The
  geometry smoke emits the expected unsupported-window-mask platform warning.
- `node tests/check-provider-model.js qml/Shelllist/Core/Model.js`: 2 checks passed.
- `tests/manual/tst_action_review.qml`: 28 passes per run, covering all 12 actual
  registered surfaces and auxiliary states with recording transports. 60 PNGs per
  run at normal/minimum geometry in light/dark. Repeated at native 1×, 1.25× and
  2× Qt scales, with Roboto Flex, Material Symbols Rounded and Nerd fallback
  fonts. The fixture asserts visible buttons are square/circular/icon-only and
  capture never dispatches a mutation. Use `Item.grabToImage` rather than QtTest's
  logical-coordinate window crop when capturing native HiDPI.
- Existing `tests/manual/tst_display_review.qml`: 4 passes including lifecycle
  hooks; reviewed trial Keep/Revert placement, explanation and initial focus.
- `git diff --check`: passed.

Local evidence: `target/circular-action-review/`, the adjacent
`circular-action-review-scale-{100,125,200}/` directories and
`target/display-settings-review/`. These are ignored review artifacts, not golden
files. Test logs are `/tmp/circular-final-{tests,lint}.log`,
`/tmp/circular-captures{,-125,-200}.log` and `/tmp/circular-smoke.log`.
Earlier full-suite runs occasionally printed Qt's existing engine-teardown
"items in the process of being created" advisory; the final 251-pass run did not.

No live service was restarted or deployed. Live compositor placement/input masks,
hardware modifiers and screen-reader acceptance remain manual checks. The full
sibling-daemon Nix gate was not run; this is a frontend-only change. The separate
binary Clipboard title-generation issue remains outside this visual migration.
