# Battery & Power presentation

The icon-first layout uses the existing `PanelSurface`, scrollable pages and
icon-only `DetailsTabBar`. It changes presentation, not daemon contracts or
acknowledgement semantics.

## Overview

Power mode comes first: a title with right-aligned saver (`eco`), balanced
(`tune`) and performance (`bolt`) circles, matching Lock & suspend's scale.
These circles are still a **single deferred segmented field**, including pointer
entry. Arrows choose a local draft; Enter/Tab saves; Escape or leaving the field
discards. The dot follows the saved value; tonal fill follows the local candidate.
Unavailable profiles, active holds and degraded-performance messages remain.
The same compact selector preserves both low/critical automatic-profile editors.

History keeps actual charge/power series, missing-data semantics, forecasts,
range editing and pointer inspection. Time/target and power direction use
icon/value pairs with full accessible descriptions. The legend still distinguishes
observed charge, discharging power and charging power; it does not replace power
areas with fictitious sample data. Exceptional and unavailable states retain words.
Application energy keeps attribution/confidence in Help and accessibility, with
`≈` for estimates, a charging icon for since-last-charge and `7d` for the week.

## Battery care

Charging & protection contains protection, resume/stop thresholds, the charge
notification, and one compact command row. The notification target follows the
acknowledged stop threshold unless protection is disabled or one-time full charge
is active, when it follows 100%. Alert and threshold save/error states stay
independent. Suppress only idle success boilerplate and repeated device/range copy.

- Alt+O: one-time full charge; retain support, AC, busy and active-override guards.
- Alt+P: pause/resume; retain inhibition support and operation guards.
- Alt+C: review calibration before starting, or directly cancel active calibration.

Calibration confirmation captures the battery identity, cancels on replacement,
and rechecks current guards. A telemetry refresh for the same battery does not
retarget the operation. Live calibration / pause / one-time status remains visible.
Device selection still appears for multiple batteries. Health and cycles use
shield/refresh readings; Hardware retains device identity, precise capacities,
desired range, kernel identity and serial information.

## Sleep and safeguards

A battery–link–plug row links source profiles. Passive battery/plug headings
replace repeated subtitles; delay editors retain explicit setting names. Monitor
+ skip conveys the lid exception; wake + cancelled timer and low-battery + sleep
convey the delayed-hibernation caveats. Section Help explains these symbols.

Critical-battery hibernation retains its explicit name, warning threshold, grace
period, countdown, cancellation and failure handling. Enabling first reviews the
single-power-manager / working-hibernation requirements in a shared confirmation;
this review is not a claim of detected readiness. Disabling is immediate.

An unavailable managed-sleep integration has a visible short warning and explicit
Details containing the unmodified backend diagnostic. Affected sleep fields are
disabled, but independent critical protection and manual commands keep their own
guards. No configuration is silently changed and no failed mutation is replayed.

## Shared presentation and validation

`SegmentedControl.circular` / `iconOnly`, option `icon` / `shortLabel`, and compact
icon-bearing `ToggleRow` / `SettingRow` are opt-in. Existing consumers keep their
resting geometry and transactions. `BatteryIconValue` is passive;
`BatterySectionHeading` composes existing Help commands, without a new key model.

`tst_battery_presentation.qml` exercises the actual panel's circular selection,
deferred pointer/keyboard edits, saved-versus-draft state, traversal, icon-only
tabs, merged charging state, confirmation modality/identity and error disclosure.
`tst_battery_suspend.qml` retains degraded telemetry, acknowledgement, inhibitor
and wire-contract checks. JS checks retain threshold/alert identity races and
history discontinuities. Run the shared Qt interaction suite and strict QML lint
when changing the reusable control presentation.
