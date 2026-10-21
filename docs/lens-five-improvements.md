# Five focused QML quality improvements

Baseline: `09fb7e8`, including the incoming Bluetooth/contract/keyboard-document
edits, which are preserved and excluded from these commits. Lens is the local
`../qmlqualitylens` at `6868f2f` (0.5.0), built with Node 24.16; Qt is 6.11.1.
Local evidence: `target/lens-refactor/`, including the incoming patch, baseline
artifacts and `snapshot.mjs`. Both snapshots use identical source discovery and
expanded normalized-clone limits (200000 keys, 1000 windows/key, 10000 groups).
Production excludes only tests/dev; full-scope figures retain them. Effort below
means Lens's weighted function heuristic, not hours or aggregate Halstead effort.
No suppressions, thresholds, test discovery or source roots are changed.

Baseline native Qt suite: **203 passed, 0 failed, 1 existing renderer skip**.

## 1. Remove retired IP editors

Lens identified `IpAddressField`, `PrefixLengthField` and `ValidatedIpField` as
unreachable. Repository and sibling QML/Nix reference searches found only their
exports and mutual implementation references; Wi-Fi already uses shared `IpField`.
Remove those controls/exports and their orphan prefix-error branch in
`FieldValidation`. Keep the active DNS list editor and complete-buffer guards.
The SystemTray Status enum finding is intentionally retained: enum-only test API
is not evidence of dead code.

Production changes: source lines **43831 → 43783**, physical lines **48702 →
48649**, cyclomatic **9395 → 9391**, cognitive **6766 → 6764**, function effort
**45813 → 45800**, clone-covered lines **1984 → 1970**. Mean leverage improves
**36.0268 → 36.2162**; mean locality falls **74.4613 → 74.2553** because the removed
small dead components were highly local. This is not an all-metric improvement.

Validation: strict QML lint; actual Wi-Fi IP field suite **8 passes**; parser
validation **106 checks**; `git diff --check`. No key, save/discard, acknowledgement
or safety behavior changes; the existing chooser keyboard contract still applies.

## 2. Share one IP validation implementation

Export the existing generated `IpValidation.js` through `Shelllist.Ui`, as already
done for MaterialIcons. Wi-Fi DNS feedback and readiness now consume that module
resource directly. Remove the second generated copy, its manifest entry, and the
pass-through `IpValidator` singleton (including eight unused methods). Update the
Nix check and native buffer-test import to the canonical parser. TypeScript remains
the source of truth; no parser algorithm, accepted input or readiness guard changes.

Production, relative to step 1: source lines **43783 → 43536**, physical lines
**48649 → 48391**, cyclomatic **9391 → 9253**, cognitive **6764 → 6649**, effort
**45800 → 45190**; normalized clone groups **118 → 111**, covered lines **1970 →
1542**, with zero omitted windows/groups. These complexity gains are duplicate/dead
code removal, not simplification of the surviving parser. Shared ownership removes
a panel-specific forwarding layer; mean locality nevertheless falls **74.2553 →
74.1777**, while mean leverage improves **36.2162 → 36.2801**.

Validation: actual Wi-Fi IP suite **8 passes**, strict QML lint, **106** parser and
**436** editor checks, generated TypeScript freshness, source-tree relative-import
check and diff whitespace check. Installed-package/Nix build was not run.

## 3. Separate owned Updates read completions

`UpdateController.finish` mixed overview, log, wire validation, pagination and
publication in one **87 cyclomatic / 96 cognitive / 395 effort** function. It now
dispatches nonempty owned IDs to reader-specific completions; history has explicit
page validation and staging boundaries. A shared failure path retires the history
request, deadline and unpublished window together. No generic request router or
new mutable owner is introduced. Stale-cursor restart bounds, identity/revision
checks, cached failures, exact-run targeting and atomic publication are retained.

The dispatcher measures **6 / 5 / 25**; the largest extracted function is history
staging at **30 / 30 / 134**. Production cognitive sum **6649 → 6638** and effort
**45190 → 45183** improve. Cyclomatic sum rises **9253 → 9255** (new function entry
points), and source lines rise **43536 → 43552**; this is a readability/ownership
tradeoff, not a LOC reduction. Locality/leverage means are unchanged.

Validation: strict lint and Updates Qt suite **25 passes**. The added regression
uses native inspect/log/refresh keys, then verifies empty, foreign and duplicate
completion IDs cannot retire another reader or overwrite its error. Existing
pagination, malformed reply, close/reopen, overview and log-cache tests pass.
Keyboard and mutation boundaries are unchanged: Updates still issues only reads.

## 4. Flatten Updates status precedence

Replace `laneOverview`'s long nested else-if chain and repeated job guards with a
small pure `laneStatus` projection. Worker running/failure/blocking states still
outrank deferred readiness; readiness outranks historical staging, and a completed
staging job still does not prove the current boot state. Snapshot availability
and readiness-read errors retain their independent meanings.

The former **27 cyclomatic / 48 cognitive / 148 effort** projection becomes
`laneOverview` **14 / 14 / 55** plus `laneStatus` **10 / 9 / 41**. Production sums
improve: cyclomatic **9255 → 9252**, cognitive **6638 → 6613**, effort **45183 →
45131**. Source lines increase by three; locality/leverage means are unchanged.

Validation: strict lint and Updates Qt suite **25 passes**. The actual Now page
now exercises running/failure/interruption/blocking/readiness/staging precedence
as snapshots arrive, with no reads or selection/focus changes. Existing unavailable,
missing-job and readiness-error cases remain covered. No interaction changes.
