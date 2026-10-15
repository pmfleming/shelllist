# Five focused quality improvements

Starting point: `bf01181`, the committed preceding Lens refactor. Each numbered
step is implemented, tested and committed separately. Local Lens 0.5.0 evidence
is in ignored `target/quality-next-five/stepN/{before,after}/`. The measurement
config retains repository roots/edges/thresholds, with execution disabled; native
lint/tests run separately. Production metrics exclude tests, dev and generated
files. These are advisory weighted metrics, not developer hours.

Planned owners: notification acknowledgements, Wi-Fi credential feedback,
system-chooser command execution, display draft reconciliation and notification
row projection. No new field/key model, mutation retry, optimistic acknowledgement
or safety exception is intended.

## 1 — Explicit notification completion routes

Capture a single request kind at admission instead of combining independent
snapshot/DND/delete flags. Dispatch catalog, policy and consent completions by
that captured kind; generic operation receipts/snapshots have their own method.
Request ownership is consumed and queued events flushed before dispatch, as
before. Cancellation remains unable to publish snapshots or clear another error.

`acknowledge` cyclomatic/cognitive/weighted effort: **21/24/104 → 10/13/58**;
new `acknowledgeOperation`: **12/13/58**. This improves peak responsibility and
removes redundant flags, not aggregate size: production function sums change
**7,998/5,478/35,592 → 7,999/5,480/35,604**, source grows nine lines. Mean
locality/leverage and expanded clone groups are unchanged. Three native cases
exercise current, newer-event and failed-operation snapshots through owned replies,
including release and no replay; existing scoped, cancellation, reply and
reentrant-completion tests remain.

Validation: full Qt **475 passed, 0 failed, 1 existing renderer skip**; strict
lint passes. No assertions, exclusions or skips were weakened. Qt runs use the
existing `QML_XHR_ALLOW_FILE_READ=1` fixture prerequisite. Full sibling Nix,
hardware/compositor, IME, human accessibility and profiler/coverage validation
are not claimed.

## 2 — Credential feedback ownership

Flatten credential-event dispatch and give keyring persistence its own method.
The active prompt's receipt/delivery/persistence feedback stays request-owned;
the retained save warning stays connection-owned and clears only for that same
connection. A late delivery still cannot hide its prompt's save outcome. No
credential handling, expiry, native prompt transaction or retry policy changes.

`handleSecretEvent` **12/24/85 → 7/7/38**; new
`rememberSecretPersistence` **5/5/26**. Production function sums change
**7,999/5,480/35,604 → 7,999/5,468/35,583**; source grows four lines. Locality,
leverage and expanded clones are unchanged. Two native cases distinguish a
same-profile save from another profile's save while a newer prompt owns delivery;
existing actual Enter, expiry and receipt/delivery/save-failure ordering cases pass.

Validation: full Qt **477/0/1**, strict lint and daemon-boundary JavaScript pass.

## 3 — Typed tray execution after shared command guards

Keep active-invocation, menu, live-result and enabled-action checks in `perform`;
use a predicate rather than retaining an unused action object. A separate tray
executor receives the uniquely resolved typed `SystemTrayItem`, not a selected
row index or inferred active application. Audio/media routes remain unchanged.
This is a responsibility/locality improvement, not a new command/navigation API.

`perform` **18/23/100 → 13/19/72**; new tray executor **6/5/32**. Production
function sums **7,999/5,468/35,583 → 8,000/5,469/35,587**; production source
shrinks one line. Aggregate complexity/effort rises slightly from the new method;
mean locality/leverage and clones stay unchanged. Native Alt+U/D/A commands act
on a prototype-looking stable tray ID; menu ownership, duplicate live identities
and deactivation block dispatch. Existing media target/capability, preferences,
Audio acknowledgement and native-menu lifetime tests remain.

Validation: full Qt **478/0/1**, strict lint and UI drift review pass.

## 4 — Display observation versus draft reconciliation

`applyDisplayPolicy` publishes the observation/results and always settles hidden
trials. `reconcileDraft` alone decides whether an authoritative trial ended,
changed topology invalidates a trial draft, a clean baseline can reload, or a
dirty draft must become stale. Trial and reset paths exit that helper early;
unacknowledged Preview observations still cannot replace or invalidate its draft.
No baseline, docking, validation, Preview/Keep/Revert or rollback guard changes.

`applyDisplayPolicy` **18/23/92 → 5/4/25**; new reconciliation method
**14/15/64**. Production sums **8,000/5,469/35,587 → 8,001/5,465/35,584**;
source grows five lines. Locality/leverage/clones remain unchanged. Three added
native observation cases cover clean reload, dirty invalidation and pending
Preview preservation, with no follow-up writes; existing actual field edits,
trial confirmation/expiry, hidden-trial reversion and topology tests pass.

Validation: full Qt **481/0/1**, strict lint, display-model JavaScript and UI drift
review pass.
