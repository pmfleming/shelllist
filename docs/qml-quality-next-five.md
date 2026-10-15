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
