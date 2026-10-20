# Five-target quality follow-up

Baseline: `3b2d9cd` (the preceding completed refactor, checkpointed separately).
Each numbered target is a separate commit. Lens is pinned to local `6868f2f`;
matched static records and execution logs live in `target/quality-five/stepN/`.
Production metrics include generated sources, exclude tests/dev, and include all
extracted helpers. Expanded clone scans retain the preceding 200000/1000/10000
limits. Native evidence is separate; incomplete profiling is not a quality pass.

## 1 — Battery timeline translation

`BatteryFlow` separates endpoint-to-delay translation from wire-duration validation,
availability, no-op detection and immutable policy publication. Never preserves the
other duration; finite pairs retain the hibernate endpoint. Selected battery/AC
profile ownership and atomic writes are unchanged. One shared duration predicate
also serves ordinary policy edits. Availability is checked once for changed positive
hibernate durations; unchanged unavailable endpoints still reject as no-ops.

`editSleepTimeline` cyclomatic/cognitive/effort **27/32/124 → 19/18/76**.
Production totals: cyclomatic **8603 → 8604**, cognitive **6078 → 6073**, weighted
function effort **42386 → 42376**, source lines **41584 → 41582**. Extraction adds
one aggregate cyclomatic point; locality/leverage and clones are unchanged.

Validation: **44,064** original/refactored differential cases, source immutability,
new total-endpoint/wire-bound and no-op assertions, existing battery-control JS,
strict lint, and native BatteryPresentation **9 passed / 0 failed / 0 skipped**.
The native suite retains actual deferred keys, Never/lid semantics, separate
profiles, unavailable hibernation, atomic pairs and explicit failed-save retry.
No interaction or daemon safety contract is changed.

## 2 — Generator-owned shared protocol validation

Framework commit **`8084fcd`** adds opt-in `--runtime-module` and `--runtime`
generation; default output stays standalone. Shelllist generates one
`Shelllist.Io.ProtocolValidation` runtime and both App/Bar clients forward their
existing APIs to it. Module imports work from original source directories and
packaged module paths. Contracts, first-error strings and validation behavior
remain daemon-generated. The runtime and consumers are checked together by the
regeneration script and the Nix protocol-binding check.

Production source **41582 → 41534**, cyclomatic **8604 → 8537**, cognitive
**6073 → 5969**, weighted function effort **42376 → 42034**. Complete normalized
clone groups **107 → 106**, covered lines **1614 → 1484**. These figures include
the new shared runtime, not just the shortened consumers. The sibling generator
itself grows to expose/test the opt-in API; this is not a cross-repository LOC win.

Validation: two generator Rust tests, warning-fatal Clippy, exact regeneration,
all 18 JavaScript scripts, strict QML lint, runtime smoke and full native Qt
**396/0/1** (existing renderer skip). A native regression exercises both clients'
module imports, independent schemas and shared local-reference validation. An
initial test used an unmodeled sleep method; it was corrected to the existing
generated `audio.adjust` contract, not by weakening validation.

The current-source Nix protocol-binding check at this step was **blocked**, not
passed: `clip-daemon/docs/quality-refactor-followup.md` was then untracked and
unrelated. It was not modified or staged. Regeneration used the explicit installed
`SHELLLIST_NM_DAEMON` override for the read-only registry command because the
sibling debug binary was absent; all five outputs compare exactly.

## 3 — Bluetooth acknowledgement and Wi-Fi status recovery

Bluetooth batch-shape/identity/value validation is independent of pending-draft
completion and per-field acknowledgement. Only confirmed applied fields disappear;
partial/unknown outcomes and snapshot failures retain their existing recovery
semantics. The captured request key is still consumed before any publication.
Wi-Fi status receipt owns the read ID, validation owns operation/stream/terminal
shape, and application owns progress/cancellation versus completion. Read failure
cannot release the mutation guard or replay a connection.

Bluetooth `finish` **19/20/95 → 5/4/23** (cyclomatic/cognitive/weighted effort);
new validation and acknowledgement helpers are included in totals. Wi-Fi
`receiveStatus` **20/20/93 → 6/5/27**, with validation **9/8/35** and application
**7/7/36**. Combined production source **41534 → 41538**, cyclomatic
**8537 → 8538**, cognitive **5969 → 5965**, effort **42034 → 42030**. Clones and
mean locality/leverage are unchanged; this is principally a responsibility split.

Validation: native Bluetooth **17/0/0**, Wi-Fi operations **19/0/0**, strict lint,
Bluetooth lifecycle (241 checks) and daemon-boundary JavaScript pass. New native
rows reject duplicate batch fields, another adapter, absent status, a foreign
stream and a nonterminal event advertised as completion. Existing actual field
save/discard, partial retry, late/duplicate reply, bounded read recovery and
cancellation acknowledgement tests remain. No backend/keyboard contract changes.

## 4 — List-owned notification viewport restoration

Move capture, incubation retries, cancellation and final scroll-memory publication
into the existing `DetailListView`, not a new wrapper. One nullable bookmark owns
key/offset/retry state; the model reference is typed. `NotificationIndex` retains
only domain publication/navigation connections. List hiding and pointer movement
cancel locally. The new actual PageDown test exposed that keyboard scrolling did
not cancel the old queued anchor; shared `DetailsNavigation.scrollPage` now does
so before scrolling. No panel-local key variant or mutation route is introduced.

NotificationIndex ID references **104 → 78**, and component effort **320 → 224**;
`restoreAnchor` cognitive complexity **17 → 13**. Counting the shared implementation,
production source **41538 → 41543**, cyclomatic **8538 → 8541**, cognitive
**5965 → 5963**, weighted function effort **42030 → 42035**. Mean locality slightly
falls **75.3631 → 75.3477** (the original index score was already floored at zero);
leverage is unchanged. The ownership/cross-object-reference improvement is real,
but not a claimed improvement in every aggregate heuristic.

Validation: full native Qt **402/0/1**, notification center **12/0/0**, chooser
keyboard **7/0/0**, strict lint, UI drift review and notification-presentation JS
pass. The native consumer test checks key plus pixel-offset preservation across
an inserted row, PageDown cancellation of late restore, missing-key retirement
and hidden-list cancellation. The standalone chooser run retains an existing
engine-teardown incubation warning. The interaction contract documents the shared
scroll cancellation boundary; daemon timeline identities/publication stay intact.

## 5 — Bounded, streaming native profiling

The adapter resolves source URLs once per event definition instead of once per
range, removes parsed XML nodes from their parents, and streams duration records
into staged JSON. No events are sampled away. Source hashes are checked after
normalization; malformed/truncated/over-limit input cannot publish partial reports.
Old reports are removed at invocation start. TERM/INT unwind subprocess cleanup,
which also kills descendants that ignore TERM or outlive the profiler parent.

The adapter records its actual offscreen/software/UTC environment; both it and
the common native runner supply trusted fixture-read permission. A direct
GeneratedContracts run with the inherited permission removed passes **4/0/0**. Recording is bounded to 180 seconds, normalization
to 60 seconds, input to 512 MiB and ranges to five million. Lens's 300-second tool
budget covers both phases and cleanup (not a relaxed test assertion or evidence
policy). Unsupported scenegraph events are no longer collected; frames and
cross-engine standalone JS attribution remain explicitly unmeasured.

Validation: eight Python tests cover units/categories, one-resolution repeated
ranges, lossless streaming, bounds, source changes, truncated input, old-report
retirement, fixture environment and timeout/outer-signal descendant cleanup.
The same suite is registered as the Nix `profilerAdapter` check. Local Python
execution passes; its current-source Nix invocation is **blocked**, not passed:
the earlier clipboard blocker is gone, but `app-daemon` now has unrelated untracked
quality-regression scripts/configuration. Those files were left untouched.
On the same saved 284-MiB trace, normalization of **3,756,343** duration events takes
**9.45 seconds / 30,548 KiB peak RSS** with the streaming sink; the old normalizer
exceeds a 30-second limit. This is an adapter benchmark, not application speedup.

Both the standalone full profiler and the actual configured Lens `measure all`
now finish. The Lens adapter takes **98.2 seconds**, reports **402 passes, zero
failures, one existing renderer skip**, and publishes **3,834,004** duration events.
Runtime-performance evidence is **complete**. Coverage correctly remains partial
(**359/396 QML files**); the JUnit skip also keeps execution scope incomplete.
The overall Lens verdict is still **incomplete**, with zero verified/semantic
failures: existing semantic abstentions and formatter limitations are not hidden.

## Combined result

Against `3b2d9cd`, production source **41584 → 41543**, cyclomatic sum
**8603 → 8541**, cognitive sum **6078 → 5963**, weighted function effort
**42386 → 42035**, clone-covered lines **1614 → 1484**. Mean leverage is unchanged;
mean locality dips slightly as noted in step 4. Component effort is effectively
unchanged (**47538 → 47539**). One new `var` is a nullable viewport bookmark, not
an untyped QObject boundary; it replaces six disconnected state properties.

Regression tests add code: full configured QML/JS physical lines grow
**57456 → 57483**. Python robustness/tests and the sibling generator also grow.
No blanket total-repository LOC or runtime-performance gain is claimed. Complete
expanded clone scans omit zero windows/groups. Full sibling release/hardware,
live compositor, IME and human accessibility acceptance remain unverified; the
unrelated sibling worktree blocker remains untouched.
