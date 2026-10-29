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
- Reads retain the accepted window on failure. Each controller bounds published
  and separately staged summaries to 200 records (plus one local creation row).
  Automatic scrolling reserves room for a complete 50-record native page, so
  byte-limited short pages can reach the boundary slightly before 200. **More
  items (Alt+M)** explicitly replaces that window; **First items (Alt+F)** returns
  to one first page. All native results remain reachable, with no catalog cutoff.
  Explicit replacement resets list selection/viewport, without publishing false
  membership or dropping saved compound creation fields.
- Same-query/day refresh starts from the window's originally issued opaque
  cursor and stages only its bounded extent before publishing once. It never
  parses/manufactures cursors or replays an older window's prefix. Stale older
  cursors retain the accepted rows and inspected editor/draft; First items is the
  explicit recovery route. There is no automatic retry loop or surprise switch
  away from an active editor. Query/day changes request one first page.
- Closing clears summary/model rows, cursors, source metadata and accepted scope.
  `AgendaRepository.retireReads` drops obsolete list/get contexts, including their
  staged rows; eventual wire completions cannot repopulate a closed owner.
  Reopening reads one first page. The single pinned full record, submitted/failed
  drafts, writes and receipt ownership remain separate and are not cleared or
  replayed. The shared full-record repository retains its existing item/byte cap.

## Interactions and drafts

- Shared `ResultRow`: single click selects; double click/Enter completes or
  reopens a capable task, or inspects an event. Right/chevron inspect without
  invoking completion. Completion first obtains a full current task when the
  row is only a summary; it never changes checklist state or list position.
- Persisted items have three icon-only shared tabs: Details, Notes, Information. Read-only
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
  Notes presents links and checklist steps in independent eight-child windows
  using shared `CollectionPager`. Previous/Next are commands (also available in
  Alt+J), never field Tab stops. Paging explicitly discards an unsubmitted field
  session without writing; submitted/failed compound drafts remain owned by the
  controller. Incoming insertions/reorders pin the active child ID in the bounded
  window, preserving its editor and begin-time revision. Child commands resolve
  IDs against the complete collection, not page-local indices. Per-item page
  anchors use the shared presentation memory; all 128 links / 512 steps remain
  reachable without instantiating all their editors.
- Schedule editing stays inside the expanded Details view (Alt+E), below Title,
  never in a modal. Its shared icon-only Mode selector offers date-only/timed.
  Field Enter/Tab saves a local compound draft; Escape discards the current field.
  Save schedule (Alt+V) submits the compound draft; Discard (Alt+X), changing the
  selected item, collapsing details or changing tabs cancels unsubmitted schedule
  validation.
  Date-only endpoints are independent, inclusive and clearable. Shared `DateField`
  provides the standard Qt month/weekday calendar with month navigation and an
  accessible date choice. Calendar clicks change the field buffer; Enter/Tab saves,
  Escape/blur discards. Arrows browse dates and PageUp/PageDown browse months while
  the calendar is open. The calendar is one field, not additional Tab stops.
  Timed input requires explicit-offset RFC3339 text and original IANA zone.
  Only explicit Save/Create invokes native `agenda.schedule`;
  successful native text validation precedes one atomic compound mutation.
  Untouched timed endpoints remain accepted instant facts, not reparsed display
  strings; only changed raw timed inputs enter the text parser. The mutation
  validates the complete final range atomically. Display can use explicit UTC/Z
  when original-zone native presentation is unavailable. There is no JS date
  domain parser, timezone inference or persisted inferred endpoint. The date
  picker's civil-date parsing is presentation/navigation only; Rust still validates
  every edited schedule and its complete range.
- Event location/people/status and task priority/status/completion are editable
  where capable. Plain notes, links, and independently identified checklist text,
  checked state, insertion, deletion and ordering use the same shared controls.
  No rich text, invitations, recurrence, attachments or reminders are implied.
- Create item (Alt+A/search plus) inserts one explicitly Unsaved list row and opens
  its expanded editor, not a popout. Title is first, then the shared icon-only
  Task/Event and date-only/timed selectors, then Start and End/due. Both dates
  default to native today (local today before the first projection), or Calendar's
  selected day, and remain clearable. Existing undated items remain undated.
  Repeating Create returns to that draft; refresh and result browsing retain saved
  local fields without inserting the draft into native membership/order data.
  Save new item (Alt+V) validates/submits; Discard (Alt+X) removes only the local row.
  Typing and field saves never create a backend item. Creation failure retains
  the draft and receipt/retry guards; no optimistic persisted item is fabricated.
  A created item outside scope opens the same inspector as a creation result
  without inserting a false day-list row.
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
Cause-first compact text is measured against the actual shared feedback label:
`FeedbackSlot.textWidth` is read-only and forwarded as `feedbackTextWidth` through
`StatusPanel` and the chooser/standalone surface owners. Agenda and Calendar use
that allocation, never a fraction of the pane width. Full accessible diagnostic
and count, shared status typography and fixed footer height are unchanged.

Geometry uses the shared measured chooser split. Agenda disables horizontal
emergency panning and shows an explicit unsupported-width state instead.
Calendar owns the shared measured 1.5W → W → hidden policy; resizing retains this
same instantiated AgendaContent and editor identities.

## Native evidence

`tests/qml/tst_agenda.qml` exercises real Qt pointer/key dispatch and the recording
shared daemon bridge: primary/inspection, field transactions and incoming drafts,
summary/lazy-get guards, malformed replies, query/reconnect/receipt ownership,
page-51 atomic refresh, inline creation/schedule failures, icon-choice/calendar
transactions, today/day defaults, draft-row retention, late validation cancellation,
read-only capabilities,
checklist independence, maximum-size bounded Notes collections, cross-page child
commands, incoming reorder/editor pinning, page-memory restoration, notes, tabs,
confirmed deletion and light/dark long text.
`tests/qml/tst_agenda_calendar.qml` owns calendar fit/focus/resize integration.
`tests/qml/tst_agenda_cache.qml` covers all 805 synthetic summaries, opaque older
cursor reuse, bounded staging, short/oversized/empty pages, stale editor retention,
query/day/late-response ownership, native boundary commands and close/reopen with
an uncertain submitted write.
These offscreen fixtures do not certify live compositor, hardware IME, human
screen-reader or production database/migration behavior.
