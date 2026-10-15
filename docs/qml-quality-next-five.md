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
