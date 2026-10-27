# Agenda frontend evidence

## Scope

`contracts/agenda-ui.md` is the UI contract. The standalone route and Calendar's
scoped route use exactly the same `AgendaContent`/`AgendaController` composition.
No Weather, Notifications, route registration or shared geometry is replaced by
this frontend change.

## Native checks

On Qt 6.11.1, offscreen/software, packaged fonts, isolated HOME/XDG and disconnected
D-Bus/Wayland (the orchestration `check.sh` wrapper):

| Check | Result |
| --- | --- |
| `tests/run-qmlquality-tests.sh -input tests/qml/tst_agenda.qml -o -,txt` | **39 passed, 0 failed, 0 skipped**, including lifecycle hooks |
| Strict `shelllist-qmllint` over the eleven new Agenda QML files and `tst_agenda.qml` | Pass, no diagnostics |
| `tst_chooser_keyboard.qml` | 4 passed, 0 failed |
| `tst_field_interaction.qml` | 8 passed, 0 failed |
| Latest `tst_agenda_calendar.qml` shared integration | 12 passed, 0 failed, 0 skipped |

The Agenda suite drives real native key/pointer events and the recording shared
`DaemonSessions` bridge. It covers single/double-click/Enter/Right, title
Enter/Tab/Escape and incoming revisions, actual modal Type/Mode dropdown choices,
clearable day defaults, title-only Create, Create/parser cancellation, parser
failure raw retention, unchanged stored timed facts, complete atomic patch
publication, event fields/people, notes, stable link retry identity, checklist
insert/check/reorder/remove and parent independence, read-only capabilities,
three tabs, confirmed deletion, stale queries/receipt/reconnect ownership, no
mutation replay, row-51 staged refresh, native reorder/editor identity and selected
record removal without an editor write, and unsupported-width key/pointer gating
without discarding a native draft. Ten concurrent native-update vectors cover
immutable begin revisions/compound baselines for every deferred inline editor
(title, notes, priority, both statuses, location, people, link label/URL and step
text). Each retains the same native editor/value through an owned get revision2,
then saves against begin revision1 and keeps the conflict draft. A failed draft's
re-entry cannot silently rebase either.

The authority regression exercises Core's actual generation advance and a
calendar-like earlier consumer callback before the repository callback: one
cache/floor reset, exactly one uncertain write failure, no replay, retained
accepted document/editor/draft through ready=false and lower-backup reads, and
explicit save still fenced to the original begin revision. Additional native
journeys assert visible nonfatal source diagnostics with usable local CRUD and
truthful epoch-zero import provenance (without hiding real local epoch values).
Latest logs: orchestration `logs/list-review-fixes-qt.log` and
`logs/list-review-fixes-lint.log`.

Two simultaneous controllers prove independent query/day/selection and shared
accepted full revisions. Summaries never fabricate omitted notes/children, and a
full owned `agenda.get` is required before a compound action/editor.

Full Rust domain/storage, package-build and live-data acceptance are separate
owners; the recording bridge is not a claim that these Qt tests started a real
agenda database or mutated a user's services.

## Captures

Actual production QML renders with synthetic native records/recording transport
are in the orchestration run's `logs/list-captures/`:

- `agenda-{light,dark}-{details,notes,information}.png`
- `agenda-creation-context.png`
- `agenda-timed-validation.png`

The retained test's optional `captureDirectory` can be supplied by a temporary
QML host; it uses `grabToImage`, waits for polish/save completion and changes no
backend transport. The local temporary host and captures remain outside tracked
code. Both themes, long title/plain notes, readable provenance/capabilities,
icon-only tabs/commands, clearable context dates and retained failed raw timed
text were inspected. Icon tokens are checked against the existing shared icon
registry. No panel-local font/spacing/radius constants were introduced.

`review-panel-ui.py --base <ref>` is advisory and does not inspect untracked new
files; new files were reviewed directly for shared `FieldRow` composition,
Theme roles and absence of local key handlers.

## Integration and limits

Latest combined calendar rerun passes **12/0/0**, including shared inspector
resize/Escape/return, generation-qualified lower-backup recovery/bounded stale
retry, and first-open nonfatal source feedback. The log is
`logs/list-review-fixes-calendar.log`. Earlier timing/readiness failures were
reported to the calendar owner; no warning was suppressed or test skipped.
Calendar owns repeated-run and three-pane/fallback capture qualification.

Native timed input uses explicit RFC3339 offsets and IANA zone, not a JS date
parser. When native original-zone display text is absent, accepted instants are
shown as explicit UTC/Z; untouched accepted endpoints are copied as facts, while
only changed raw timed endpoints pass through native text validation. The final
compound range is always validated by the native mutation. This is not inferred
scheduling or timezone arithmetic.

Loaded summary pages accumulate for the current query; full payload cache is
bounded separately. Inactive long shared TextField values can show their retained
cursor's suffix; the header retains the title beginning and the native accessible
value is complete. A panel-local cursor reset was deliberately not added because
it would violate shared cursor/session memory.

No live compositor, hardware IME, human screen-reader, destructive user data,
physical device or daemon migration/persistence acceptance was performed here.
Recurrence, reminders, attachments, invitations and remote writes remain deferred.
No quality lens or post-implementation quality refactor was run by this worker.
