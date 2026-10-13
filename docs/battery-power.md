# Battery & Power presentation

The icon-first layout uses the existing `PanelSurface`, scrollable pages and
icon-only `DetailsTabBar`. It changes presentation, not daemon contracts or
acknowledgement semantics.

## Overview

Power mode comes first: a title with right-aligned saver (`eco`), balanced
(`balance`) and performance (`speed`) circles, matching Lock & suspend's scale.
Glyphs use very desaturated sage, blue-grey and sand mixed with theme foregrounds.
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
Charging command glyphs use muted sage (one-time full charge), sand (pause/resume)
and blue-grey (calibration). The title and icons share one row with an extra
shared small-spacing inset above, separating it from the preceding field line.

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

Lock & suspend uses muted sand (coffee), sage (lock), blue-grey (moon) and
lavender (hibernate) glyphs on neutral command circles. Keep awake retains its
acknowledged accent fill and contrasting glyph when active. There is no separate
Retry/reset-looking button or Alt+T command; explicit lock/sleep commands remain
available under their existing capability and operation guards. Pending, error
and unknown-outcome diagnostics still contribute to the fixed surface footer.

The Power page uses three sibling shared task cards: **Lock & suspend** for
immediate commands, **Automatic sleep** for lid/source policies, and **Critical
protection** for low-battery safeguards. Battery levels, automatic power profiles
and hardware tuning continue below them, unchanged. No new tab or global Apply
control is introduced; all cards share the existing controller/operation owners.

“Same settings on battery & AC” visibly names the link switch. Passive source
headings say “Battery & plugged in”, or “On battery” and “Plugged in” with both
profiles visible when unlinked. “Current” follows the reported active profile,
not a guessed source. Labels wrap without shrinking the switch. “Suspend after”
and “Then hibernate” keep full inactivity/suspended-time meanings in accessibility
and Automatic sleep Help. Help also explains docking, System default, the lid
profile exception, waking, low battery and Keep awake; the old caveat pictogram
strip is removed. Source labels and headings are not editable stops.

Automatic sleep ends with compact diagnostic Details and Retry settings commands;
Retry retains Alt+R and the original dirty/error/critical-only guards, including
critical-only retry when managed sleep is unavailable. Details remains in the
shared Alt+J command menu. Neither enters field Tab traversal.

Critical protection uses “Hibernate at critical battery”, revealing “At or below”
and “Warn for” only when enabled. Its independent Help explains prerequisites,
AC escape and per-episode behavior. The reserved “Cancel this battery episode”
command retains Alt+C, its full accessible name and in-flight/phase guards.
Critical-battery hibernation retains its warning threshold, grace
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
It also covers sibling task-card composition at 453/340px in both themes, long
labels, linked/unlinked field traversal, deferred sleep edits, independent critical
confirmation/retry while managed sleep is unavailable, and countdown cancellation.
`tst_battery_suspend.qml` retains degraded telemetry, acknowledgement, inhibitor
and wire-contract checks. JS checks retain threshold/alert identity races and
history discontinuities. Run the shared Qt interaction suite and strict QML lint
when changing the reusable control presentation.

Task-card validation: an isolated HEAD checkout plus only this change passed
strict QML lint and the full Qt suite (617 passed, zero failures, one existing
renderer skip), with `QML_XHR_ALLOW_FILE_READ=1` for local protocol fixtures.
Ignored evidence in `target/suspend-task-cards/` includes 28 native offscreen
captures: 453/340px, light/dark, shared/separate profiles, Keep awake, unavailable
managed sleep and critical countdown. These use synthetic state and recording
transports, not real sleep/hibernate requests or hardware acceptance.
