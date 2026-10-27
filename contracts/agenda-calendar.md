# Agenda calendar surface contract

## Ownership and composition

`agenda` and `calendar` are independent lazy catalog routes, each with an independent
`AgendaController`. Calendar's controller owns one `agendaController`; its selected
civil date is the controller's `dayScope`. `AgendaCalendarContent` embeds the exact
same `AgendaContent` provider surface, list, creation dialogs and inspector used by
standalone Agenda. No duplicate day-list implementation or frontend membership.
Weather and Notifications remain available. The legacy `activity` CLI/global/IPC
name canonicalizes to Agenda, without an advertised Activity descriptor, separate
controller or launchable old Glance/Schedule composition. Notifications back routes
and old bar activity actions target Agenda. Old internal QML remains only for its
existing tests and Time/Weather's shared controller dependency.

`agendaShortcut` and `calendarShortcut` are independent nullable Home Manager
options, defaulting to null. Both named global routes remain available. The local
Hyprland Lua binding audit found Super+A already assigned to Activity and Super+T
to Time & Weather (along with the existing shell/system/application bindings);
this change does not guess or replace a Super chord or edit user configuration.

## Measured fit

`Ui.CalendarComposition` consumes the provider's actual `currentWindowWidth`,
`closedWindowWidth` W, shared gap and actual work-area edge margin. In order:

1. 1.5W calendar + visible shared provider composition, when it fits.
2. W calendar + the identical provider composition, when it fits.
3. Hide calendar only after a date is selected; retain the provider composition.

Before day selection, calendar stays visible. Return to calendar (Alt+B and the
host back button) retains selected date, focus date, month anchor and pixel offset.
The internal route bar keeps the selected date readable beside Back, including
when the calendar is hidden; that label is passive and outside the grid. Calendar/list
share the same available vertical body below this route bar.
No layout transition reinstantiates the provider or inspector, saves/discards a
field or replays a mutation. Native editor identity and drafts survive fit changes.
`ChooserController.compositionWidth` opts only this host into measured outer width;
ordinary provider split measurements remain unchanged. Calendar opts out of the
shared emergency horizontal viewport. Below the existing supported provider split
envelope, this does not invent a fourth layout; clipped unsupported sizes require a
separate shared-UI validation gate. `CalendarComposition.supported` exposes that
boundary. Vertical overflow remains native.

## Calendar viewport and input

One month spans all calendar width. Nine consecutive months form a bounded vertical
ListView window (under 370 civil days). The first invocation begins at the current
month. Approaching either window edge rebases around the top visible month while
retaining its pixel offset; previous and next commands move that top month by one,
Today returns to today's month. Reopening retains the bounded window/offset.

`Ui.PanelSurface.scopedNavigation` registers the shared `DateGridNavigation`
non-field region. Its focused grid owns Left/Right (+/-day), Up/Down (+/-week),
PageUp/PageDown (+/-month, clamping day), Enter (choose date). There is no panel-local
Keys handler. Native editors/results retain their own keys. Calendar and provider
command registries are input-scoped and share existing modal/menu guards. Tab does
not turn date cells, headings, presence marks or commands into editable fields.

Calendar-only intentional content geometry is owned by Agenda: 44px date targets,
six date rows, seven equal columns, a month/weekday heading allocation and 5px
presence marks. Typography uses shared heading/metadata/label roles; FocusRing
provides marker-only browsing, independent of selected-date fill and today's
outline. Date accessibility names include full date and presence, never item titles.

## Native data and fences

`agenda.markers` supplies event/task booleans, today, timezone and catalog revision
for the bounded date window. QML never infers membership from records, counts,
titles or task completion. Events are dots; tasks are squares. Completed tasks stay
represented because completion is not a frontend presence predicate. No titles,
counts, legend, range heading or hover previews appear in the grid.

`AgendaCalendarMarkers` is the internal native-read owner, exposed by the calendar
controller as `markerWindow`; selection, fit and viewport remain in the controller.
It owns the daemon subscription, pending read and accepted marker window, with a
separate transport-authority state. Cached `catalogRevision`, days, today and timezone
remain presentation through a disconnect. Only an actual shared daemon session
`generation` change resets the authoritative revision floor, never ordinary activation
or a ready notification alone. `AgendaRepository.synchronizeTransportAuthority()`
idempotently qualifies the shared floor with that same actual generation, including
calendar-only use while the repository transport is inactive. Pending replies must
still match the actual generation when consumed. Fresh lower revisions after a
verified backup/restart can replace old presentation; older same-session replies
cannot. Its non-mutating metadata/day validators build an unpublished candidate;
validation cannot partially replace an accepted prefix. The controller consumes
read-only presence/today instead of duplicating this transport state.

A nonempty owned request ID + requested range + active invocation fence publication.
An accepted or failed owned reply consumes its read once; empty/unknown/duplicate
IDs cannot publish or retire another read. Invalidation clears ownership before
its debounce, including native activity/timezone events and repository changes.
A full validated response publishes atomically; malformed/out-of-range/duplicate dates,
nonboolean presence, stale revisions and failures retain accepted markers. Activity,
timezone, acknowledged stream gaps and accepted-mutation invalidation request new native projections; active
periodic healthy/idle reads cover midnight/resume without storing inferred dates.
One stale-window response may restart its read once. Repeated stale responses,
malformed windows or read errors retain presentation/error and pause automatic
polling until an external invalidation or explicit fresh read request. The periodic
fallback cannot refill the retry budget. No mutation replay is involved.

Additive native `failing_source_count` and cause-first `source_error` describe nonfatal
provider health on the same successful marker snapshot. Omitted legacy metadata is
healthy; present malformed metadata rejects the entire read. These accepted fields
survive failed reads/disconnects with the marker presentation and clear only on an
accepted healthy window. `AgendaCalendarGrid` contributes through shared
`FeedbackSource`/`PanelSurface` fixed feedback, including before any selected-day list
is active. Full bounded native text/count stay accessible; measured compact prefixes
keep the actual cause visible for long configured source labels. No frontend error
classification, source-management controls, editable stops or local-write blocking
is added. Unsupported recurrence cannot masquerade as complete single-event support.

## Evidence

`tests/qml/tst_agenda_calendar.qml` exercises real Qt date keys/pointer/accessibility,
modal blocking, both-direction bounded rebasing, first-open/reopen memory, exact
measured thresholds, malformed/stale/error retention, empty/duplicate ID rejection,
native reader subscription activation and immediate invalidation fences, lower-revision
reconnect/inactive recovery, same-session floor retention, bounded stale retries and
paused polling, direct native source-warning feedback with retained local editability,
actual registry icon resolution, identical shared inspector
editor retention on resize, Return and disabled horizontal overflow. The existing
`tst_agenda.qml` owns full shared list/inspector transactions and domain acknowledgements.
`tests/surface-catalog.nix` checks separate nullable defaults and configured commands;
the generated catalog freshness and CLI tests cover route generation and the
legacy Activity alias (including floating mode).

Offscreen recording transports do not certify live compositor masks/placement,
physical touchpad/IME, human screen readers, exhaustive localization or package
builds. Those acceptance gates remain separate.
