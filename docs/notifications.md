# Notification center

The notification center uses the shared chooser, identity header, circular actions,
compact settings fields and bottom tabs. The left list always contains applications.
There is one notification collection, not separate All/Live modes. Each app row
leads with the newest notification's content (subject/body without duplicate text).
Its secondary line is time · app · total notifications, with Silent appended when
applicable. Search-match counts remain available in the accessible name; they do
not replace the total. This presentation does not change app-row command scope.

## Actions and settings

- Each application row has **Silence** and **Delete**. Alt+Q/Alt+D target the selected
  app, including while details are collapsed. Pointer commands target their own row.
- Expanded app headers promote **Silence/Unsilence** to their single filled
  primary. **Reset app defaults** (Alt+E) and **Delete** are secondary circles;
  reset is no longer a standalone row below the settings.
- Silence suppresses popups while retaining notifications. App controls support
  indefinite/30-minute/one-hour silence, exact-repeat grouping, DND bypass and reset.
  These policies are daemon-owned, persisted and published only after storage ack.
- Delete prepares a 60-second native confirmation snapshot. App deletion includes
  every retained notification from that app, including entries outside search;
  global deletion does the same for the entire collection. Individual deletion
  targets the exact record. New arrivals are excluded. Cancel and expired tokens
  never mutate notifications. In-flight deletion survives IPC caller cancellation.
- A confirmed delete removes stored records and closes any corresponding popup.
  Storage errors do not optimistically remove active records. Uncertain completion
  is reported, not automatically retried. App preferences survive deletion.
- Global settings use the standard DND switch/duration field, confirmed Delete
  all command, and per-app override resets (including apps with no remaining
  notifications). App sound playback, popup-body privacy and configurable retention
  from the exploratory HTML are not exposed: those require separate capabilities.
  This implementation adds no sound player or automatic history pruning.

## History, keyboard and rendering

Notifications shows the **three newest matching notifications** individually,
then **Today**, **This week**, **This month**, and **Older**, initially closed.
The previews are excluded from these four mutually exclusive groups. The daemon
uses local calendar dates: today first, then the week beginning Monday, then the
remaining month, then older records. Empty groups retain disabled headers. Only
one period opens at a time; opening it seeks directly to that period.

Counts and previews come from `notifications.queryCenter` with `period_groups:
true` over its documented recent search scope, not from the loaded slice. Windows
contain at most 20 entries and append on scroll; they are not user-facing pages.

Only exact, fully represented, action-free summary/body/category/urgency matches
within an application and date stack, in groups of at most 50 records. Long or
actionable messages remain separate. This deliberately avoids guessing conversation
identity from similar text or exposing hidden bulk sender actions. Stack members
retain their own timestamps, Read and Delete commands.

Shared `DetailListView` gives virtualized read-only detail content the same Tab
fallback and PageUp/PageDown behavior as `DetailFlickable`. Up/Down remain app
navigation. Read opens Message without invoking an app or changing read state.
Message alone owns guarded sender actions and explicit reply sending. App controls
use ordinary Enter/Tab save and Escape discard transactions.

Native continuation reads are revision/epoch/local-calendar-day fenced. Midnight
refreshes the period counts even without arrivals. Replacements stage through
the old window before publishing recent previews and period entries together;
partial failures leave the previous snapshot.
Deletion invalidates readers to prevent old responses from restoring removed
records. The record identity is always `(id, created_unix_ms)`.

## Icon identity

The daemon captures desktop-file `Icon=` independently of content image hints and
persists it as `identity_icon`. Its bounded desktop registry is built on a blocking
worker at daemon startup, with XDG directory precedence. Newly installed/changed
desktop entries require a daemon restart to refresh that registry. Existing history
can resolve desktop identity at query time. No remote artwork is fetched.

The shared QML resolver uses captured identity, desktop theme name, sender app icon,
known exact app aliases and installed app-name icons. `image-path` / `image-data`
never represent the application. Missing/failed app images use an app initial in
the existing icon tile (a bell only for unnamed senders). Notification bodies never
identify an app. Transient content-image caching/enrichment is intentionally not
part of this change.

## Deployment and verification

Rebuild/restart **bar-daemon and shelllist together**; the frontend requires the
additive timeline, policy and deletion protocol methods. There is no local catalog
fallback. SwayNC retains its existing managed-settings notice; native-only controls
are disabled.

Qt tests: `tst_notification_center.qml`, `tst_notifications.qml`,
`tst_notification_icons.qml`, plus shared navigation and bar suites.
Rust tests: `activity::notifications`, including `redesign_tests`.
