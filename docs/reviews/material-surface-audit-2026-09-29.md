# Material 3 surface audit — 2026-09-29

## Verdict and scope

**The shared visual foundation is substantially Material-derived; the surfaces are not uniformly finished Material 3 interfaces.** The largest gaps are information hierarchy, appropriate control selection, discoverability and accessibility—not a need for another palette/shape redesign. Power and Displays deserve the first layout/content pass.

Material does **not** mean replacing all words with icons. Short labels, current values, error explanations and consequential-action text are useful. The avoidable verbosity here is mostly permanently visible implementation documentation, repeated save-policy explanations and technical metadata placed ahead of controls.

Reviewed all 12 registered chooser/panel surfaces, plus the bar, OSD, notification toasts and shared dialogs. This is a **source audit with fresh offscreen visual inspection of Power and Displays**, not a live visual/accessibility certification of every surface. No production code changed during this review. Preserve the owner's approved appearance, contained Tab/Enter workflow and common tonal focus treatment.

Reference working tree: HEAD `44584db`, including the existing uncommitted maintenance and navigation/focus changes. SHA-256 of `git diff HEAD -- '*.qml' '*.js' '*.ts'` at review: `54ac497543f76dcccce404ec10abfdf0a54494f07cdc297c3c28d146bac7911c`.

### Basis

- [M3 switches](https://m3.material.io/components/switch): on/off settings; named controls.
- [M3 buttons](https://m3.material.io/components/buttons) and [icon buttons](https://m3.material.io/components/icon-buttons): action hierarchy and recognizable actions. Common buttons have descriptive labels; compact icon buttons are valid, not inherently noncompliant.
- [M3 lists](https://m3.material.io/components/lists): distinguish headline, supporting information and trailing controls.
- [M3 tabs](https://m3.material.io/components/tabs): related content at the same hierarchy level. Icon-only tabs are allowed; icons must still communicate the destination.
- [M3 dialogs](https://m3.material.io/components/dialogs): clear purpose, accessible naming and explicit actions.
- Upstream [Material Web documentation](https://github.com/material-components/material-web/tree/main/docs/components) for these components was fetched during the review. It is a useful semantics/component reference, not a complete M3 Expressive specification or a Qt implementation mandate.
- Local [visual foundation](../material-visual-foundation.md), [product decisions](../proposals/material-expressive.md), and [keyboard workflow](../chooser-keyboard-workflow.md).

Distinguish **component/accessibility defects**, **information-design recommendations**, and **deliberate desktop adaptations**. The latter include bottom-positioned inspector tabs, compact dimensions, the custom browse/edit keyboard boundary, no automatic tooltips, and tonal rather than outlined focus. Do not silently reverse these product decisions under the name of compliance.

## Highest-priority findings

### 1. Notifications can browse an invisible action — confirmed defect

`activity/NotificationHistoryRow.qml:26,112` reveals quick actions on hover, reply state or native focus. `qml/Shelllist/Ui/NotificationQuickActions.qml:9` checks only `activeFocus`. The new browse cursor sets `browseFocused` without transferring native focus.

A fresh Qt reproduction selected `notificationQuickSnooze` with `browseFocused == true`, native focus false, and its containing row at **opacity 0**. Thus the control's tonal focus indicator is also invisible. The user can arrive at a hidden actionable target.

**Recommendation:** reveal the actions immediately for browse focus as well as native focus, without executing them or moving selection on hover. Add a regression through the real notification inspector. Toast controls have a separate hover/reply-only reveal rule and need their own keyboard/reachability review; do not assume fixing the inspector fixes toasts.

### 2. Display Preview and Identify have the same icon — confirmed ambiguity

`displays/DisplayProvider.qml:62–75` assigns `󰈈` to both **Preview changes** and **Identify**. Both render as an eye, while shared buttons suppress the visual label when an icon exists. One operation trials a whole display layout; the other identifies a monitor.

**Recommendation:** distinct, recognizable actions. A persistent short **Preview** label is justified for this consequential command if the owner approves that exception; otherwise choose genuinely distinct icon semantics. Do not add automatic hover labels or weaken preview/revert safety. Keep the explicit **Keep / Revert** labels already in the trial dialog.

### 3. Critical-battery safety guidance is elided — visible in the fixture

`battery/BatterySuspendPolicyPane.qml:199–200` puts “do not enable a second power manager” inside a `ToggleRow` subtitle. `ToggleRow.qml` elides subtitles to one line. At the normal 453px panel width the warning is truncated.

**Recommendation:** keep the toggle's supporting text short and put the operational warning in a wrapping, contextual message when enabling/configuring protection. Removing background prose must not remove this warning, active countdown, cancellation limits, inhibitors or unknown-outcome information.

### 4. Dialog overflow and accessible container semantics need closure

`qml/Shelllist/Ui/ModalFrame.qml:68–75` clamps card height and clips a non-scrollable column. Long required-input content or larger text can therefore leave lower content/actions outside the visible card. The shared frame also has no explicit accessible dialog role/name association; a painted heading alone is not equivalent to a named dialog.

**Recommendation:** scrolling body with reachable actions and appropriate dialog/alert semantics. Preserve the existing modal focus trap, safe default actions, native IME, layered Escape and secret clearing. Overflow is a source-derived risk requiring long-content/large-text reproduction, not a claim that every current prompt clips.

### 5. Power profiles bypass the agreed browse/edit boundary — confirmed

`battery/BatteryProfileSelector.qml` exposes separate `ActionButton` radio choices rather than one shared setting editor. `DetailsNavigation` therefore treats them as commands. A fresh Qt probe focused `profileOption-power-saver` in browse mode and pressed Enter: it immediately recorded `powerProfile.set`, rather than first entering editing.

**Recommendation:** use the shared single-choice setting pattern (or an explicitly supported composite editor), keeping acknowledged values and disabled guards. This is a violation of the agreed desktop interaction contract, not a claim that Material universally requires Enter-to-edit.

## Power / Battery: detailed review

### What is already good

- Prominent percentage, charge/time/power telemetry, history chart and application-energy comparison are meaningful visual information—not prose to delete.
- Native sliders, switches, capability guards, save/error state and acknowledged values are present.
- Care and overview are separated; charge-limit validation and observed-versus-desired state are retained.

### Main gaps

1. **Everyday actions are last.** `PowerControlsPane.qml:16–59` renders low/critical levels, hardware tuning and the full automatic-suspend policy before `BatterySuspendPane`. Lock/suspend/hibernate/Keep awake are consequently at the bottom. In the normal healthy fixture, content was **1153px high in a 638px viewport**.
2. **Too many unrelated jobs share the Suspend tab.** Low-battery profile switching, hardware tuning, lid behavior, inactivity timers, critical hibernation and immediate system actions are not one flat task.
3. **Idle states read like documentation.** `BatterySuspendPolicyPane.qml:89,259,278` always explains managed lid behavior, internal phases, failure retry policy and countdown-reset implementation—even with protection disabled and nothing pending.
4. **Care exposes implementation ownership before user outcome.** `BatteryProtectionPane.qml:34` leads with “Managed by bar-daemon · observed …”; technical hardware identity and calibration are given almost the same prominence as charge limits. Desired/observed differences matter, but the daemon name normally does not.
5. **The icon-only profile selector is a bespoke radio-button row.** `BatteryProfileSelector.qml` uses separate 36px colored buttons rather than the shared single-choice control. It lacks a visible current-profile name and makes icon knowledge do the work. This is a consistency/discoverability issue, not a prohibition on icon-only controls. `BatterySuspendPane.qml` also hardcodes a purple suspend color rather than using a semantic theme role.

### Recommended hierarchy, retaining existing capabilities

- **Overview:** charge/time hero → current power mode → history → application energy. Retain estimates/confidence and missing-data states.
- **Power / Sleep:** immediate actions at the top; a compact Keep awake state; lid action; inactivity and subsequent-hibernation rows; critical-battery protection as a distinct group.
- **Battery care:** protection toggle and existing paired charge sliders; charge-once action; a health/cycle summary. Calibration, raw hardware identity and hardware tuning belong in explicit secondary sections. Active calibration/cancel/error state must remain discoverable even if its settings section is collapsed.
- Use optional supporting text only when it changes the decision: an error, unusual override, missing capability, relevant dependency or pending/unknown outcome.
- Disabled critical-protection options can be disclosed when configuring that policy instead of displaying several inactive rows and a paragraph at rest.

Examples of shorter **presentation**, not changed behavior:

| Current emphasis | Better default presentation | Must remain available |
|---|---|---|
| Managed by bar-daemon · observed 75–80% | Charge range · 75–80% | Whether desired and observed thresholds differ; firmware refusal |
| Multi-sentence lid-policy paragraph | Lid closed → selected action | Docked exception; system-policy ownership; profile delay meaning |
| “State: disabled. Requires working hibernation…” | Critical-battery protection · Off | Enablement warning and capability failure; active countdown/cancel |
| Repeated “Changes apply automatically…” | Saving / Saved / Failed when relevant | Retry, unknown outcome and acknowledged value |

Do not replace all of this with cryptic icons or hide the limits of hibernation. Do not combine threshold controls in a new range widget unless its native editing, validation and acknowledgement contracts are preserved.

## Displays: detailed review

### What is already good

- The spatial arrangement canvas, numeric positioning alternatives and monitor identification are appropriate to the task.
- Resolution/refresh/scale controls already form a useful compact grid.
- Layout changes remain drafts, with a timed trial and explicit Keep/Revert. Information is already separated from settings.

### Main gaps

1. **Focus is a configuration manual.** `DisplayFocusModel.js` defines **26 settings in four groups, including 15 booleans**. `DisplayFocusSetting.qml:27–76` renders a help paragraph, a dropdown even for on/off values, and a raw compositor key for each entry. The fully supported fixture is **3536px high in a 522px viewport**, about 6.8 viewport lengths.
2. **Introductory prose displaces the controls.** `DisplayFocusPane.qml:43–73` explains global scope, persistence, history shortcuts and override restoration before the actual settings. In the fresh capture, only the first setting and the beginning of the next are visible below this introduction.
3. **Scope and commit policy are visually mixed.** The selected-monitor header surrounds global Focus settings. `DisplayDetails.qml:55` still displays the layout-drafting instruction on the Focus tab, where the page says settings save automatically. Docking policy is also immediate, while adjacent mode/position edits require preview.
4. **Display-content behavior is explained instead of structured.** `DisplayInspector.qml:54–62` persistently explains extending, mirroring, black bars and mirror-source promotion. Only some of that applies to the current choice.
5. **The first view favors form fields over the spatial model.** Arrangement is optional while raw X/Y controls sit in the main settings flow. This is an information-design recommendation, not a requirement to eliminate keyboard positioning.

### Recommended structure

- **Layout/settings:** compact arrangement representation where useful → selected display enablement → Extend/Mirror choice → mirror target only when relevant → resolution, refresh, scale and orientation.
- Keep precise coordinates and relative-position controls in an explicit Position section. Never make dragging the only way to arrange displays.
- Provide a clear **Unsaved changes / Preview** status-action area only where layout changes apply. Summarize affected outputs rather than repeating a tutorial.
- **Focus:** clearly identify **All monitors**. Put common pointer/window/monitor behavior first. Render the 15 booleans as compact labelled switches, multi-valued settings as appropriate choices, and numerical values as native fields. Put advanced exceptions/history/warp rules in secondary groups.
- Remove raw `input:…` / `misc:…` keys from the default view; retain them in explicit technical details. Keep short dependency explanations beside affected controls.
- Show restore-override semantics when the user chooses that operation, not as a permanent paragraph above every visit.
- Use concise scope labels for immediate global/docking settings. **Do not unify these with layout preview or silently make layout edits immediate.**

For mirroring, preserve explicit source identity, capability checks, prevention of invalid chains and warnings about affected copies when a source is disabled. The whole-layout preview/rollback mechanism remains non-negotiable.

## Review of every registered surface

Priority is work order, not a numerical conformance score. Except for Power and Displays, these assessments are source-based, not fresh full-state screenshot acceptance.

| Surface | Assessment | Targeted next improvement / evidence |
|---|---|---|
| **Applications** | Mostly aligned hierarchy | Search/results, instances/actions, resources and settings are sensibly separated. Preserve the resource charts and retained-history notice. Inspect repeated header/list metadata and shared two-row action-toolbar overhead rather than adding decorative cards. `launcher/ApplicationDetails.qml`, `ApplicationPage.qml`, `ApplicationResourcesPage.qml`. |
| **Wi-Fi** | Medium priority; diagnostic-heavy | The normal view contains Connection and Network detail tables before profile settings. Security begins with a 245px device-identity table, including profile path, before its controls. Move diagnostics behind explicit technical disclosure; keep connection/sign-in status and useful settings first. Do not simplify enterprise credentials or remove inline IP validation. `wifi/NetworkDetailCards.qml`, `AdvancedSecurityPane.qml`, `AdvancedIpSettingsPane.qml`. |
| **Bluetooth** | Mostly aligned device view; denser settings | Battery artwork, noise control and audio are good task-oriented presentation. Adapter/device settings repeat technical and ownership information. Keep connection/radio/audio defaults prominent; move addresses/controller identifiers to technical detail. Long adapter lists should not become a cramped segmented row. Preserve pairing verification, trust/reconnect semantics and acknowledgement. `bluetooth/BluetoothDevicePage.qml`, `BluetoothDeviceAudio.qml`, `BluetoothAdapterSettings.qml`. |
| **Clipboard** | Mostly aligned | Preview/editor is primary and metadata has its own tab; failed drafts have explicit retry/discard. Avoid empty Images/Files/Dimensions metadata for irrelevant types. Test long filenames and fixed-height metadata under larger text. Do not hide unsaved drafts or put ordinary text editing into a modal. `clipboard/ClipboardDetailCards.qml`. |
| **Displays** | High priority | Correct safety machinery, but excessive explanatory forms, global/local scope mixing and ambiguous Preview/Identify icons. See detailed findings. |
| **Battery / Power** | High priority | Good controls/data, weak task ordering, permanent implementation prose and a truncated safety warning. See detailed findings. |
| **Activity** | Medium priority | Glance cards are useful; schedule/agenda/todo can feel like nested bordered panels rather than a clear hierarchy. Today is available both in the outer header and schedule header. Day-navigation buttons expose literal `‹` / `›` as names via `ActivityHeaderButton`, rather than “Previous day” / “Next day”. Keep the overview as a glance, not a full date-picker redesign. `activity/ActivityContent.qml`, `ActivitySchedulePane.qml`, `GlanceScheduleCard.qml`. |
| **Notifications** | High priority for focus defect | Grouping, clipped body with explicit expansion, reply drafts and recovery are useful. Fix invisible browse actions first; review 26px action targets and default-card activation accessibility. Message text is content, not explanatory clutter to delete. `activity/NotificationHistoryRow.qml`, `qml/Shelllist/Ui/NotificationQuickActions.qml`. |
| **Time & Weather** | Mostly aligned information design | Hero time/weather, visual solar/lunar data and forecast rows already communicate visually. Improve small-text legibility: literal 9px metadata exists in `TimeWeatherTimePane.qml` and `WeatherHourlyForecast.qml`; fixed hero heights need large-text validation. Preserve units, location/timezone, forecast uncertainty and unavailable-data states. |
| **Audio** | Medium priority; underdeveloped content | Details mainly offer mute, with ±5% volume controls in the header. A compact in-content volume value/stepper is more discoverable and supports the browse/edit model. The inspected route exposes delta volume, not an absolute slider setter: do not invent that capability or a device inventory. Keep full-mixer access. `bar/SystemChooserContent.qml`, `SystemEntries.js`, `SystemChooserController.qml`. |
| **Media** | Medium priority; preferences dominate | The details body emphasizes pin/automatic/mode rather than now-playing and transport. Give playback the primary hierarchy; keep selection/mode as secondary preferences. `SystemEntries.js` always supplies a play glyph and “Play/pause”, even for playing media—reflect the actual available action. Shorten “Automatic (unknown content seeks ±30 seconds)” to a concise choice plus relevant supporting state. Preserve explicit player targeting and capabilities. |
| **Tray** | Medium priority; generic inspector | Generic icons and an almost-empty details body underuse supplied application identity. Prefer the actual tray icon where available and an obvious menu/activation path; retain ambiguity guards and the native menu boundary. Vendor menu content itself is not Shelllist-controlled Material UI. `bar/SystemEntries.js`, `SystemChooserContent.qml`. |

## Bar, overlays and shared components

- **Bar:** the continuous surface, stable groups and restrained pictorial status are consistent with the accepted desktop direction. Do not add persistent track/artist text. The 18px-wide overflow control and narrow hit regions need a pointer/touch-target review (`bar/BarContent.qml:106–117`). Native tray/menu behavior remains outside a blanket conformance claim.
- **OSD:** the concise icon/value/progress layout is appropriate. It is a custom status surface, not automatically a stock M3 slider; preserve immediate confirmed-value feedback. Multiple borders/badges are a low-priority consistency concern, not justification for redesign (`bar/BarOsdContent.qml`).
- **Notification toasts:** useful urgency/grouping/reply structure. Small controls and hover-only reveal require accessibility scrutiny. Preserve timing, drafts and explicit dismiss/snooze behavior (`bar/NotificationToastCard.qml`).
- **Dialogs:** the labelled Display Keep/Revert dialog is a good safety exception to icon-only actions. Retain pairing codes and password instructions. Address shared overflow/name semantics as above; do not turn consequential actions into unexplained symbols.
- **Shared type/targets:** `Theme.qml` uses a custom compact scale (13px body, 11px caption, 42px normal and 38px compact controls). Several consumers go down to 26–36px targets. These are desktop density decisions, not exact M3 token conformance; evaluate effective hit areas and larger text instead of claiming that matching radii is sufficient. Do not automatically enlarge every control to a mobile size.
- **Shared action hierarchy:** `DetailsHeader.qml` reserves separate primary/secondary action rows, which can consume substantial space even when all actions are icons. Review the spatial cost and primary-action prominence. Keep hotkey-only header traversal intact.
- **Focus:** keep the requested borderless tonal treatment. Verify visibility/contrast in both themes, selection and disabled states; automated palette checks do not alone establish contrast of every layered focus state. No return to heavy rectangular rings is proposed.
- **Update logs:** the route opens an external terminal running `journalctl`; there is no separate Shelllist Material log surface to grade (`bar/BarController.qml:289–290`).

## Implementation order and acceptance criteria

1. Fix invisible notification browse feedback and the Power profile browse/edit exception, distinguish Preview/Identify, and make critical-battery warnings fully readable. Close dialog overflow/accessibility risks with reproductions.
2. Reorder Power and remove default-state implementation prose; restructure Display Focus and condition the layout status area on the relevant context.
3. Review Wi-Fi diagnostics and the small Audio/Media/Tray inspectors. Then polish Activity naming and shared small targets/type.

For Power and Displays, the first viewport should contain useful state and actionable controls—not a manual. Use semantic labels, at most brief supporting copy in the ordinary state, and explicit secondary disclosure for advanced/technical information. This is a design target, not a fabricated Material word-count rule.

Acceptance must include normal and constrained widths, dark/light themes, larger text, pointer and the agreed Tab/Enter/Ctrl+Tab journeys, disabled/pending/error states, unsupported capabilities, backend disconnection, display hotplug during a trial and cancel/unknown-outcome paths. Reflow must preserve stable focus identities, domain drafts and acknowledgement/recovery. Do not make hidden advanced settings lose active warnings or recovery actions.

## Evidence and limits

Temporary review probes and screenshots are in `target/material-surface-review/`:

- `tst_capture.qml`: synthetic data, existing recording daemon transport, actual QML components; **3 probes / 5 Qt passes including hooks**. The notification and Power-profile reproductions pass by asserting the defects, not by fixing them.
- `power-top.png`, `power-middle.png`, `power-bottom.png`, `battery-care.png` at 453×780.
- `display-settings.png`, `display-focus-top.png`, `display-focus-settings.png` at 1040×780.
- Upstream component reference documents cached alongside the probes.
- Log: `/tmp/material-surface-review-captures.log`.

Captures use Qt 6.11.1's offscreen/software backend and the existing packaged Roboto Flex / Material Symbols / Noto / Nerd Font fontconfig. Initial captures without that fontconfig showed fallback ligature words and were replaced; those were harness artifacts, not production icon defects. Reported content heights are from the corrected-font fixture and are not universal measurements for all states.

The regular 286-pass gate from the previous implementation remains historical evidence for that implementation; this review did not rerun or extend that gate. No live compositor, hardware IME, screen reader, scaling or full-state visual acceptance is claimed. No deployment/restart or production UI changes occurred.
