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
| `tests/run-qmlquality-tests.sh -input tests/qml/tst_agenda.qml -o -,txt` | **50 passed, 0 failed, 0 skipped**, including lifecycle hooks |
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
Implementation checkpoint `dd68cfaf71d24a954d7653605c070eafa9343654` passed39
cases. The quality phase retains those journeys and adds seven malformed
header/document and four mutation-acknowledgement vectors through the recording
native bridge: rejected records retain the accepted window/floor, rejected
acknowledgements retain their owned draft, and neither can replay a mutation.
Latest native/lint logs are in
`target/agenda-quality-list-after-owned-20261027-1745/` (`native-qt.log`,
`native-lint.log`); current calendar12/shared-field8/shared-key4 passes are retained
there separately.

Two simultaneous controllers prove independent query/day/selection and shared
accepted full revisions. Summaries never fabricate omitted notes/children, and a
full owned `agenda.get` is required before a compound action/editor.

Full Rust domain/storage, package-build and live-data acceptance are separate
owners; the recording bridge is not a claim that these Qt tests started a real
agenda database or mutated a user's services.

## Quality-driven refactor

Actual qmlqualitylens0.5.0 measured the same eleven production files before and
after with one evaluator and identical policy (only output directory differs).
Controller list/mutation completion now separates request ownership, shared wire
validation, projection/continuation decisions and validated publication. Full
records and summaries use one identity/provenance/capability/schedule header;
document-only notes/children remain mandatory for full records. This is a
behavior-preserving refactor, not a new protocol or weakened guard.

Measured cyclomatic/cognitive values: receiveList41/40 →10/9,
receiveMutation25/30 →7/6, validItem34/33 →5/4, validSummary23/22 →4/3.
Scope/bindings remain11 files/571 bindings. Clones remain unchanged (shared modal
and field composition); no suppression/threshold change was made. Raw reports,
source archive, configs and comparison are under
`target/agenda-quality-list-{before-owned-20261027-1735,after-owned-20261027-1745}/`.
Static reliability remains incomplete because this deliberately production-only
scope does not discover tests and lacks imported tool/type context; it is not a
claim of correctness. Actual native tests/lint above are separate evidence.

## Final package feedback-width correction

The first immutable frontend package check after quality commit `e00cbf1` failed
one source-diagnostic case (588 passed, 1 failed, 1 existing RHI skip). Native
checks with the same Fontconfig file still passed outside the sandbox: that file
includes host `/etc/fonts/conf.d`. A private `FONTCONFIG_SYSROOT` excluding host
configuration reproduces the failure without changing packaged fonts: requested
and resolved Roboto Flex13px, label371px wide/30px high, guessed budget212.5px,
actual text `unsupported iCalendar recurrenc…`.

The correction forwards the actual `FeedbackSlot` label width read-only through
shared footer/surface owners; Agenda and Calendar elide against that width rather
than half a pane. No typography, padding, footer height, full accessible diagnostic
or count changes. Existing native cases retain their cause assertions and now
also check exact font-metric elision against the real allocation, accessibility
and unchanged footer height through resize/fallback.

Evidence: `target/agenda-final-feedback-fix-20261027/`. In the reproducing font
sysroot, focused Agenda50/0/0 and Calendar12/0/0; full native suite589/0/1(existing
RHI skip). Strict lint on all seven modified production QML files plus both
native test owners is clean. Supplemental actual seven-file lens has identical
before/after policy/evaluator: zero parser diagnostics,34 static review findings
unchanged, no suppressions; advisory score77→76 with the additional forwarding
bindings, not a correctness verdict. Raw reports and both-theme native captures
are retained. The new immutable Nix frontend qualification is still the
orchestrator's separate gate; these local runs do not claim it passed.

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

A fresh quality-phase capture run also passed50/0/0 and saved the same eight
views plus `agenda-source-diagnostic.png` under
`target/agenda-quality-list-after-owned-20261027-1745/native-captures/`.
The diagnostic image shows the actual cause-first unsupported-recurrence text
with a retained usable local row; no HTML screenshot was substituted. UI
composition/paint code is unchanged by the refactor.

`review-panel-ui.py --base <ref>` is advisory and does not inspect untracked new
files; new files were reviewed directly for shared `FieldRow` composition,
Theme roles and absence of local key handlers.

## Integration and limits

Latest combined calendar rerun passes **12/0/0**, including shared inspector
resize/Escape/return, generation-qualified lower-backup recovery/bounded stale
retry, and first-open nonfatal source feedback. The log is
`target/agenda-quality-list-after-owned-20261027-1745/calendar-qt.log`. Earlier timing/readiness failures were
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
Quality artifacts are static/advisory; they do not close these live acceptance
gates or replace the native interaction owners.
