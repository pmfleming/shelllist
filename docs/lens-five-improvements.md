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

## 5. Simplify structured IP inspection

Extract subnet inspection beside the existing pure parser and combine address /
subnet validity using the native validator ordering (Invalid < Intermediate <
Acceptable). This removes nested mask/prefix handling from `inspect`, retains
invalid raw notation and the -1 noncontiguous-mask result, and preserves the whole-
value length/configuration/suffix gates and optional-wholly-empty exception.
Change the TypeScript source and regenerate the QML JavaScript; do not hand-edit
or weaken the generated parser to improve metrics.

`inspect` improves from **35 cyclomatic / 62 cognitive / 202 effort** to **25 / 33 /
120**, with `inspectSubnet` at **7 / 7 / 33**. Its individual token Halstead effort
falls **74776.40 → 40554.65**; the new helper is **6862.65** (not an aggregate
Halstead calculation). Production sums improve **9252 → 9249** cyclomatic,
**6613 → 6591** cognitive and **45131 → 45082** weighted effort. Source lines fall
by three; physical lines by one.

Validation: **444** editor and **106** parser checks; native structured control
suite **16 passes**, actual Wi-Fi fields **8 passes**; strict lint, TypeScript
`--noEmit` and generated freshness. Added independent vectors cover invalid-versus-
incomplete precedence and optional empty-pair boundaries. A separate deterministic
frozen-input comparison of old/new complete inspection records passes **115614**
cases, including unsupported configurations and malformed inputs. It remains
ignored local evidence, not a substitute for native editor tests.

## Combined result and remaining limits

| Metric | Production before → after | All analyzed sources before → after |
| --- | ---: | ---: |
| Source lines | 43831 → 43552 | 50492 → 50263 |
| Physical lines | 48702 → 48411 | 55572 → 55331 |
| Cyclomatic sum | 9395 → 9249 | 10044 → 9903 |
| Cognitive sum | 6766 → 6591 | 7022 → 6851 |
| Weighted function effort | 45813 → 45082 | 50703 → 50022 |
| Mean leverage | 36.0268 → 36.2801 | 32.4422 → 32.6234 |
| Mean locality | 74.4613 → 74.1777 | 75.7866 → 75.5558 |
| Normalized clone groups | 119 → 111 | 160 → 152 |
| Clone-covered lines | 1984 → 1542 | 2537 → 2095 |

Both complete clone inventories omit zero windows/groups. Tracked code across
QML/JS/TS/scripts/Nix/Rust, including tests, falls **64326 → 64096** physical lines.
Cleanup reviews fall **4 → 1**; the retained enum stub is not dead-code proof.
No new escape hatches: production `property var` **523**, unknown-signal escapes
**0**, lint disables **15** are unchanged. **Escape-hatch counts and measured
locality did not improve.** Smaller live functions and one parser owner improve
review locality conceptually, but that is not a measured locality-score gain.
Protocol payloads, heterogeneous models and editor snapshots remain intentional
dynamic boundaries; blindly narrowing them would not be a safe quality improvement.

Final validation: complete native Qt suite **204 passed, 0 failed, 1 existing
software-renderer skip**; strict lint; both offscreen Quickshell runtime smokes;
TypeScript freshness/typecheck; relative-import check; UI review **0 prompts**;
whitespace check. The original five modified files' diff is byte-for-byte unchanged.
No test removal, new skip, numeric style override or interaction change was used.
The smoke retains the offscreen window-mask warning. No hardware/compositor/IME,
human accessibility, installed-package build, full sibling-daemon contract campaign,
coverage/performance or formatting acceptance is claimed. Lens semantic coverage
remains partial; these structural improvements are not a complete audit pass.
