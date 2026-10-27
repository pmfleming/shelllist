# Shared Agenda UI contract

`AgendaContent` and `AgendaController` are the single list/editor implementation
for standalone Agenda and Calendar's day-scoped list. Calendar supplies only
`dayScope` and host back commands. Each controller owns its query, selection,
loaded window, expansion and shared chooser presentation memory independently.

## Reads and acceptance

- `agenda.list` returns native-ordered `summary:true` records, at most 50 per
  requested page (the daemon can return fewer to satisfy its byte limit).
  No QML membership, scoring, completion filtering or sorting is performed.
- Summaries omit notes, links, people and checklist. Only `agenda.get` and
  successful mutation/receipt records can supply editable full values.
- `AgendaRepository` shares accepted full revisions, not presentation state.
  Its cache is bounded to 32 records and an estimated 8 MiB UTF-16 serialized
  payload; each controller additionally retains its inspected full record.
  `synchronizeTransportAuthority()` reads the actual shared bar session generation
  directly (including before consumer failure callbacks finish). It resets only
  the generation-qualified authority floor/cache/request epoch, once per actual
  generation change. Accepted windows and pinned document/editor identities are
  retained. Uncertain submitted writes fail exactly once, never replay.
- Query/day generations and transport epochs reject obsolete completions.
  Continuations must agree on catalog revision, today and timezone. Duplicate
  identities, malformed children and wrong mutation identities fail closed.
- Reads retain the accepted window on failure. A same-query refresh stages pages
  through the previously loaded extent before publishing once. Results use the
  shared keyed list/viewport composition. Scrolling lazily requests later pages;
  there is no arbitrary 500-row cutoff. Loaded summary pages accumulate until
  a replacement query/refresh; full document payloads do not accumulate there.

## Interactions and drafts

- Shared `ResultRow`: single click selects; double click/Enter completes or
  reopens a capable task, or inspects an event. Right/chevron inspect without
  invoking completion. Completion first obtains a full current task when the
  row is only a summary; it never changes checklist state or list position.
- Exactly three icon-only shared tabs: Details, Notes, Information. Read-only
  metadata has only the shared non-highlighted scrolling fallback. Known unknown
  epoch-zero read-only import provenance is shown as Unknown; legitimate local
  epoch timestamps and known imported timestamps are not hidden.
- Shared `FormField`/`FieldRow` and native shared editors own ordinary field
  Enter/Tab save and Escape discard. Typing, blur, tab changes and layout do not
  write. `AgendaInlineEdit` captures immutable full target ID/kind/revision and
  compound/child-ID baseline at the shared session's begin boundary. Save uses
  that original revision even if a native read advances while typing; no
  save-time rebase is allowed. Conflict retains the submitted value/baseline;
  re-entry still requires the existing explicit reviewed Retry to rebase.
  Cancellation/new target/finished session clears only the transient capture.
  Incoming revisions preserve keyed child editors and active buffers.
- Schedule is one contained shared modal. Date-only endpoints are independent,
  inclusive and clearable. Timed input requires explicit-offset RFC3339 text and
  original IANA zone. Only explicit Save/Create invokes native `agenda.schedule`;
  successful native text validation precedes one atomic compound mutation.
  Untouched timed endpoints remain accepted instant facts, not reparsed display
  strings; only changed raw timed inputs enter the text parser. The mutation
  validates the complete final range atomically. Display can use explicit UTC/Z
  when original-zone native presentation is unavailable. There is no JS date
  parser, timezone inference or persisted inferred endpoint.
- Event location/people/status and task priority/status/completion are editable
  where capable. Plain notes, links, and independently identified checklist text,
  checked state, insertion, deletion and ordering use the same shared controls.
  No rich text, invitations, recurrence, attachments or reminders are implied.
- Shared Create/Cancel accepts title-only. Day context supplies visible clearable
  dates. A created item outside scope opens the same inspector as a creation
  result without inserting a false day-list row.
- Delete is revision-checked and confirmed. Modal guards suspend underlying
  field, result, tab, calendar and Alt command navigation.
- Saved invalid/failed values survive for explicit retry. Retry reads current
  full data and confirms a reviewed rebase of only the saved field; unedited
  compound children are preserved. `agenda.receipt` checks uncertain outcomes,
  including creation. Reconnect/refresh never replays a mutation.

Successful list reads also accept native nonfatal `failing_source_count` and
`source_error` metadata. Existing shared feedback and the existing information
modal disclose the bounded native source diagnostic (including unsupported
recurrence) without clearing accepted rows or blocking local CRUD. Read failures
retain previous accepted diagnostics; a healthy accepted read clears them.

Geometry uses the shared measured chooser split. Agenda disables horizontal
emergency panning and shows an explicit unsupported-width state instead.
Calendar owns the shared measured 1.5W → W → hidden policy; resizing retains this
same instantiated AgendaContent and editor identities.

## Native evidence

`tests/qml/tst_agenda.qml` exercises real Qt pointer/key dispatch and the recording
shared daemon bridge: primary/inspection, field transactions and incoming drafts,
summary/lazy-get guards, malformed replies, query/reconnect/receipt ownership,
page-51 atomic refresh, modal creation/schedule failures, read-only capabilities,
checklist independence, notes, tabs, confirmed deletion and light/dark long text.
`tests/qml/tst_agenda_calendar.qml` owns calendar fit/focus/resize integration.
These offscreen fixtures do not certify live compositor, hardware IME, human
screen-reader or production database/migration behavior.
