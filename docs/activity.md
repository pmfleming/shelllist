# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened by right-clicking the bar's Notifications group, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- a month calendar and selected-day agenda;
- persistent todos and source-health reporting.

Time/weather, notification previews and DND controls are not part of Activity.
Time & Weather and Notifications remain separate surfaces, reachable from the
bar, their commands and global shortcuts.

The bar bell opens Notifications; its right-click route opens Agenda. **Super+Shift+N** opens Notifications directly (installed by the Home Manager module when Hyprland is enabled; configurable with `programs.shelllist.notificationsShortcut`, or see the README binding). The search gear (Alt+Enter from search) opens Notification settings even when the list is empty. DND and its duration live there, not in a standalone power button. Saving duration while DND is off only selects the next duration; while on it restarts DND with that duration. “Until turned off” has no expiry. The switch and deadline show daemon-acknowledged state; failed writes offer retry.

Alt+S captures the complete visible Activity panel through `clip-daemon` and copies the image to the clipboard and clipboard history, just as in every other Shelllist surface.

Popup-visible notifications appear in up to three compact notification stacks per monitor. Normal server-default popups hide after five seconds without closing the live notification; it remains actionable in the center. Explicit client expiry, dismissal or sender closure makes a record read-only. Transient notifications are not retained in history. Server restart archives old conversations rather than reviving their actions. A stacked toast shows only its newest record and a count badge; its chevron opens that group in the separate Notifications callout. `shelllist notifications open|toggle` and the `notifications` global shortcut open the pane directly.

The surface uses one searchable **app-group list**, permanently retained on the left, and **Overview / Notifications / Message** detail tabs. Overview shows at most three previews, Notifications at most five compact entries per page, and Message one explicitly selected record. Read commands select that immutable record and switch tabs without invoking sender actions or marking it read. Message is disabled until selection. The daemon supplies counts and live/retained records without duplicates; there is no Active/History switch. Alt+S copies a screenshot through `clip-daemon`. Inline replies and 15-minute snooze remain capability-dependent. There is no history-deletion control.

Overview and Notifications separate previews into passive, padded tonal cards with clear gaps. A distinct subject uses heading-size semibold text, content uses normal body text (at most two lines), and time/lifecycle metadata uses smaller muted caption text. Missing or repeated app-name subjects are omitted rather than turning a long body or file path into a headline. Each card retains a low-emphasis 32px Read chevron with a full accessible name and Alt+J route; the card itself has no click action or field stop. Full, unabridged text remains in Message.

When entered from Activity, Back or `Escape` restores Activity's calendar/detail state. Direct entry closes back to the desktop. The close button always closes. `F5` refreshes notifications. Up/Down selects an **app**, Right/Left expands/collapses, and Enter always opens Notifications—even for a singleton app. It never invokes an implicit message action. Ctrl+Tab cycles enabled detail tabs. Notifications' shared Page field seeks only on Enter/Tab save; Escape discards and Alt+P/N pages. Read commands are also available through Alt+J, outside field traversal.

Notification action icons and shortcuts exist **only in expanded Message**: Alt+O opens, Alt+D dismisses, Alt+Z snoozes, Alt+C copies text, Alt+R opens/sends inline reply and Alt+J lists sender actions. Hidden pages register nothing. Only the exact `inline-reply` action opens the editor; ordinary sender reply actions remain ordinary app actions. Search and replies have no printable single-key shortcuts. Selected identities survive arrivals; missing records show unavailable instead of silently selecting the next message.

Panels follow the [mandatory interaction contract](chooser-keyboard-workflow.md): Tab traverses editable fields, Enter/Tab saves, and Escape discards the current field edit. Todo entry uses Alt+A to add; Alt+D deletes the currently browsed todo. Alt+R sends the current reply; Alt+J opens other content actions. Saving a reply field retains its draft, rather than sending it.

Saved reply drafts are shared with toasts and retained in memory when views close, filters change or records update. Uncommitted panel-field edits are discarded on leaving. Only an acknowledged successful reply clears the matching draft; failures retain it for retry. Drafts are not persisted across Shelllist restarts.

## Ownership

Shelllist owns only:

- Hyprland/Quickshell layer-shell surfaces and monitor placement;
- month, agenda, todo, notification, and world-clock rendering;
- selected date, viewed month, focus, scroll, selected message and open tab;
- locale-aware labels and time formatting;
- animations and input;
- translation of user intent into `bar-api` calls.

`bar-daemon` owns durable data, source health, ordering, range bounds, mutations, retries, notification IDs, expiry, timed DND, snooze wakeups, grouping metadata, and SQLite history. Shelllist must be restartable without losing Activity state.

## Data and presentation flow

Activity uses the [shared anchored chooser geometry](chooser-geometry.md), not a
separate full-height right-edge panel. Its glance rail stays on the left while
Schedule expands to the right. Logical work-area bounds come from QScreen and
the event-driven daemon work-area stream; the frontend does not poll geometry.
The rail contains only the calendar/schedule summary, starting at the top.
Schedule expands its agenda/todo detail pane while preserving the rail.
`Ctrl+2` expands Schedule; the former `Ctrl+1` and `Ctrl+3` cross-surface shortcuts
are removed. Within Activity, `Escape` returns to the glance panel before closing
the surface. Activity and Time & Weather do not construct or update notification
state; only the resident notification owner subscribes to its streams.

Time & Weather follows the same list/detail interaction as Wi-Fi and Bluetooth. The list combines configured weather locations and world clocks by timezone, showing city, current weather, and local time. `Right` expands the selected city. The detail pane has **Time** and **Weather** tabs; Time renders a world map that highlights every region sharing the selected current UTC offset and marks configured location coordinates, plus sun position, day length, and moon phase. Weather reuses the existing hourly, daily, and weather-metric presentation. The bar clock/date group opens this chooser directly.

Network-aware timezone updates are owned by the system location authority, not
by a panel-open or weather-refresh action. Its concise warning arrives through
`timezone.error` and is contributed to the existing Time & Weather status bar
using `FeedbackSource`, including when details are collapsed. No inline warning
or tooltip is added. A warning does not invalidate the observed system timezone.
The visible top-bar clock/date and its accessible description both render the
daemon's `utc_offset_seconds` using UTC getters, so an acknowledged timezone
change takes effect without restarting Qt or relying on its local-time cache.
Configured Home/weather places are not changed by this path. The authority asks
GeoClue first, accepts positively identified IP fallback directly, and otherwise
requires matching canonical coordinate-derived IP/GeoClue timezones (no distance
limit). Missing confirmation retries without changing the observed timezone.
Accepted current-location coordinates may be coarse IP estimates, not precise
physical position. Current location retains its stable ID/title; its shared list
and detail subtitles show e.g. **IP estimate · reported accuracy ~26 km**. Unknown
source/accuracy is not guessed, and reported accuracy is not a guaranteed radius.
Estimate metadata remains passive and gains no field/navigation stops. The separate
explicit location commands described below do not turn metadata into editors. The authority also
retains manual choices across restart, blocks NetworkManager-reported VPNs,
revalidates stale GeoClue caches and respects confirmation cooldowns. These guards
remain backend-owned. Session offset updates use a cached zone locally across DST;
accepted-state revisions avoid repeated authorized reads when nothing changed.
The panel's list and details share one `Ui.LiveClock`, refreshed immediately on
activation and scheduled at wall-clock minute boundaries while open. Closing
stops its timer; reopening never reuses the previous visit's time. Each tick
reschedules from the current wall time rather than accumulating interval drift.
These display refreshes make no backend requests. The daemon calculates each
location's current offset, abbreviation and map regions locally from its IANA
zone at a shared projection instant, independently of forecast availability or
cached provider offsets (including across DST). Missing/invalid zones carry
`clock_unavailable: true`; the panel shows unavailable time/date rather than UTC
and does not highlight a guessed timezone band. Real UTC remains valid.
`tst_timezone_clock.qml` retains the clock button's live acknowledged offset
changes. Native timezone and location tests own DST, invalid evidence and durable
updates; Qt location journeys retain acknowledged manual selection and protected
removal. Passive estimate/forecast/theme matrices are retired; see
[current coverage](../tests/test-reduction-owners.md).

### City and current-location management

Home is protected Amsterdam (`Europe/Amsterdam`), supplied by native product
policy—not compiled into QML. A house denotes Home and a target denotes Current.
When the acknowledged effective place shares Amsterdam's canonical timezone,
the native list shows Home only: no separate Current item, Current icon or Current
metadata on Home. Home's coordinates/map/weather remain Amsterdam's. Current is a
single populated entry away from Home, never a blank placeholder. With no usable
accepted location, omit that entry; retain the last accepted place during acquisition
without inventing a city. Unknown location is not Home, and equal current UTC offsets
do not establish timezone identity. Saved cities
in the same timezone remain independent. Arrival home hands selection to Home
where the filter permits, retaining the detail tab; departure never steals it.

The existing search trailing plus opens Add (Alt+Enter from search / Alt+A).
Every city and both tabs share one Manual-location primary (Alt+L), and Automatic
(Alt+R) / Remove (Alt+D) secondaries. Protected and unavailable actions retain
geometry. List Enter only opens details. Manual opens the shared city picker,
prefilled with the inspected place; explicit confirmation sets the system timezone
and pauses automatic location. It does not change Home or implicitly save a city.
Return to Automatic changes policy but retains the last effective place until fresh
accepted evidence arrives. It remains reachable on Home when Current is suppressed.

The picker has one searchable City control using shared required-input modal
traversal. Type to search, Down/Up to browse suggestions, then Enter or click to
choose. Selection stays local; only explicit confirmation submits. Escape closes
suggestions before cancelling the modal. Add/Manual use their identity glyphs;
Cancel sits beside Confirm in the header, without an action-summary footer. Removal confirms the captured
saved-city identity and never removes Home/Current. Late replies cannot retarget
another picker or claim success on request admission. Failures remain separate from
Activity read status, with shared surface feedback and no automatic write replay.

`bar-daemon` imports weather/world-clock configuration once into versioned
`locations.json` beside its todo store. Calendar configuration is still read from
`activity.json`; later city refreshes cannot reimport removed entries. A previous
non-Amsterdam Home is retained as an ordinary saved city. Corrupt catalogs fail
closed with protected Amsterdam still visible. Add/remove requires catalog revisions;
per-city forecast caches survive unrelated changes. New city clocks work before a
forecast is available. Online city search uses bounded Open-Meteo geocoding reads;
Current itself does not start weather or reverse-geocoding requests; it can reuse
a matching saved city's forecast, never another city's merely matching timezone.

The system authority owns authorized Manual/Automatic controls, private durable
mode/operation state, coordinate/zone validation and verified timedated writes.
The session daemon is only a proxy/observer. Lost replies use read-only status
recovery; external overrides and uncertain writes still require administrative
reconciliation. Older/missing authority support leaves commands unavailable—no
frontend shell-command fallback. Deploy the matching session daemon, location
authority and system-bus/polkit policies together. See the sibling backend's
`docs/time-location-catalog.md` and `docs/time-location-controls.md`.

Shelllist requests only a buffered calendar range around the visible month.
A compact `activity.changed` event schedules a debounced range refresh rather than
carrying that range in every event. The native daemon refreshes Open-Meteo forecasts
at most every 15 minutes after successful fetches and retains each last successful
forecast through transient failures. Forecast requests are bounded so city mutations
do not wait indefinitely behind provider I/O.

In native notification mode, `bar-daemon` owns `org.freedesktop.Notifications` and publishes a bounded, recoverable snapshot containing only unsnoozed active records. That stream drives toasts and current action capabilities, not a second frontend history catalog. `notifications.queryCenter` merges live/persisted identities and supplies native app summaries, ordering, counts, Unicode-lowercase literal substring search, direct app-page seeks and selected full-record lookup. Search covers the newest 5,000 persisted records plus up to 200 unsnoozed live notifications, not merely loaded pages. This query limit does not prune stored history. Search uses the full body even though previews are bounded.

App identity prefers desktop entry, otherwise the trimmed, case-sensitive app name. Artwork never splits an app group; distinct desktop IDs remain separate even when names match. Unnamed or overlong identities conservatively remain separate records; these descriptive keys are never mutation-routing authority. App order follows its newest matching record. Search counts distinguish matches from the app's total in the recent scope. Conversation `group_key` remains independent; toast group links resolve to an app natively.

The frontend requests up to 50 app summaries or one app snapshot containing three Overview previews, five index entries, count/page metadata and optionally one full selected message. It never downloads all bodies or groups loaded pages. Previews retain bounded `hints.image_path` and `hints.desktop_entry` alongside `app_icon`, so list/header icons use the same supplied artwork as full messages and toasts, including archived records. Theme lookup prefers an exact icon, then its standard `-symbolic` variant before trying the next sender/app hint. Missing/unresolvable artwork still uses the neutral bell; icons never determine mutation identity. Native responses are byte-bounded to 512 KiB. App-page continuation is fenced by epoch/content revision; a refresh stages through its previous app anchor and atomically replaces the visible window. Direct seeks are native, not frontend cursor replay. Same-page refresh uses a record anchor; an in-flight explicit seek takes precedence over an old anchor. Late reads cannot overwrite new queries/selections or retire newer reads. Failures retain coherent cached pages, without mutation replay. Unsupported APIs fail visibly without a JS catalog fallback. The older `notifications.queryHistory` daemon API remains available to legacy clients; Shelllist has no legacy history loader or fallback.

One resident notification backend owns the shared state; the bar reads it rather than writing its own notification snapshots back. Equal snapshots, popup visibility and DND-only changes do not rebuild center rows or reload history. Reply drafts and operation acknowledgements remain keyed by notification ID plus creation time. Atomic replacements and page appends preserve stable selection, the top visible row/offset and active reply editor; the old window remains visible while a same-query replacement loads. Loading, unavailable, failed, empty and no-match states are distinct. Event gaps refresh the resident snapshot and schedule an active center refresh independently; hiding the center invalidates its read generations, not submitted mutations. See the [interaction contract](chooser-keyboard-workflow.md#notifications-app-groups-and-detail-tabs) and `tst_notifications.qml` for validation coverage.

Toast stacks and legacy group links use the same grouping policy:

1. daemon-provided `group_key`;
2. desktop entry;
3. application name;
4. a final generic fallback.

The daemon captures the focused output as `source_monitor` when a notification arrives. Shelllist routes its active stack to that output when it still exists, otherwise to the focused output, then to the first available output. This routing is transient presentation policy; the source monitor remains daemon-owned record data.

Removal animation is presentation-only. Dismiss, clear-group, clear-all, snooze, action, and reply requests are sent to `bar-daemon`, which validates current state and publishes the resulting snapshot.

## Frontend contract

| File | Responsibility |
| --- | --- |
| `activity/ActivityApi.js` | Activity and notification method/stream registry |
| `activity/ActivityBackend.qml` | Calendar/todo/weather transport adapter |
| `activity/ActivityController.qml` | Ephemeral calendar range, selection, and presentation state |
| `activity/NotificationState.qml` | Shared live records, revision tracking, reply drafts and mutation state |
| `activity/NotificationBackend.qml` | Notification requests, acknowledgements and stream adapter |
| `activity/NotificationController.qml` | App selection, per-app tab/page/record memory and command guards |
| `activity/NotificationCatalog.qml` | Bounded native app/detail reads, generations and atomic refresh |
| `activity/NotificationDetails.qml` | Shared three-tab layout with active-page loading |
| `activity/NotificationIndex.qml` | Bounded passive previews, Read commands and transactional page field |
| `qml/Shelllist/Ui/NotificationIconSource.qml` | Shared icon-source resolution; existing IconTile consumers own rendering/fallback |
| `activity/NotificationContent.qml` | Standalone notification surface and return navigation |
| `activity/ActivityContent.qml` | Anchored calendar/agenda/todo composition |
| `activity/ActivityGlancePane.qml` | Calendar and schedule summary |
| `activity/TimeWeatherContent.qml` | City list and two-tab Time & Weather composition |
| `activity/TimeWeatherTimePane.qml` | Local time, sun position, moon, and timezone detail |
| `activity/ActivityWeatherPane.qml` | Reusable local weather and forecast detail |
| `activity/ActivitySchedulePane.qml` | Calendar, selected-day agenda, and todo detail |
| `activity/NotificationHistoryRow.qml` | Selected-message inspector |
| `bar/NotificationToastStack.qml` | Monitor-local active groups |
| `qml/Shelllist/Ui/NotificationPresentation.js` | Shared grouping, routing, and DND labels |

`ActivityContent.qml` contains no filesystem, provider, subprocess, persistence, or notification-policy integration.

## Notification presentation

Browse, Read and Page use registered semantic symbols through the shared icon
renderer, not literal text in a Nerd Font. Commands retain their accessible
names and shared command-menu routes, without entering field traversal.
Notification icons use supplied local images or positively resolved installed
icons (including desktop/name fallbacks), otherwise a neutral bell. Missing theme
assets must never be represented by Quickshell's checkerboard placeholder;
failed local images use the same shared glyph fallback.
Previews promote the body when the summary only repeats the app name. Distinct
subjects remain headlines; Overview body excerpts use normal text size and at
most two lines, with date/lifecycle metadata on a separate caption. Index titles
stay single-line. Text remains plain, passive and bounded, and Read still targets
the original record identity, not its presentation text.
Direct entry reserves no hidden Back/options row below search. Agenda entry
still exposes its Back command. All detail pages share horizontal content insets;
the fixed tab footer stays full-width. Read circles use the shared expanded
secondary size (32px/16px), retaining a clear hierarchy below the 56px primary.
Qt tests cover both wide and narrow layouts, mapped content bounds and Back/Read
pointer routes.

## Validation

The checked `bar-api` fixture validates `bar/BarApi.js` and `activity/ActivityApi.js` against the backend registry. Focused checks are:

```sh
tests/run-qml-tests.sh
nix build .#checks.x86_64-linux.barDaemonContract
nix flake check
```
