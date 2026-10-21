# Next five Lens-guided improvements

Baseline: `2816e75`, including the five incoming Bluetooth/contract/keyboard-doc
edits, preserved outside these commits. Analyzer: local `../qmlqualitylens`
`6868f2f`, version 0.5.0; Node 24.16, Qt 6.11.1. Evidence and reproducible snapshot
script: ignored `target/lens-refactor-next/`. Same source scope and normalized
clone limits as the preceding review: 200000 keys, 1000 windows/key, 10000 groups;
no omitted windows/groups. Production excludes tests/dev only. Weighted effort is
a structural heuristic, not hours. No suppression, threshold or test discovery change.

## 1. Typed selection contract and provider-owned append

Add `Core.SelectionModel` for index/query/count and bounded movement. ResultStore,
Time/Weather and Notifications now implement the same typed chooser boundary;
test doubles use it too. Catalog reconciliation remains domain-owned: the shared
model intentionally does not clamp when count changes. Notifications keeps its
key-derived index and overrides movement through its existing guarded selection.

Clipboard no longer reaches through the generic selection object to invoke
`ResultStore.applyNormalizedBatch`. Its history append uses the provider controller's
existing query API with an append flag, preserving provider/query checks and keyed
selection. This removes a dynamic interface and duplicate movement implementations,
not domain data validation or the JSON payload boundary.

Production: source lines **43552 → 43544**, physical **48411 → 48404**, cyclomatic
**9249 → 9246**, cognitive **6591 → 6590**, weighted function effort **45082 →
45065**. Mean locality **74.1777 → 74.2613**, leverage **36.2801 → 36.3964**;
`property var` **523 → 522**. Clone counts are unchanged. SelectionModel leverage
is 75; ResultStore locality improves 89 → 90 and TimeWeatherController 77 → 78.

Validation: strict lint and full native Qt suite **205 passed, 0 failed, 1 existing
renderer skip**. Native chooser keys additionally check last-result clamping; a
Clipboard transport-boundary test checks append, stable selection and stale reads.
No interaction change: Up/Down browse results, search entry and field transactions
retain the chooser keyboard contract. Notification selection side effects and
Time/Weather's native identity restoration remain owned by those controllers.

## 2. Give DNS validation one shared editor owner

Move `AddressListField` to `Shelllist.Ui` and co-locate its saved-validation state
and messages. `FieldValidation` had only this remaining caller after retirement
of the legacy address/prefix editors. Remove its unused single-address mode,
forwarding properties and the obsolete NetworkInput module. Wi-Fi and the manual
form fixture use the shared editor; Nix lint already discovers its new location.
Preserve the old diagnostic translation context with `qsTranslate`.

Production source/physical lines decrease **22**, cyclomatic **2**, cognitive **3**
and weighted effort **8**. The editor's locality rises **92 → 100** and mean
leverage **36.3964 → 36.4608**. Removing the fully local wrapper lowers mean
locality **74.2613 → 74.2078**. Normalized clone coverage rises **1542 → 1554**;
this is a simplification of live ownership, not an all-metric improvement.

Validation: strict lint, actual Wi-Fi IP suite **8 passes**, **106** parser checks,
source-tree import check and whitespace check. Native DNS assertions verify no
pre-save feedback, retained full-buffer rejection, family-change reset and no
backend writes. Shared TextEditor still owns Enter/Tab/Escape and multiline keys;
DNS remains one field in FieldRow, with domain readiness and acknowledgement intact.

Rejected candidate: extracting all Updates schema predicates into one new module
passed 2223 frozen-input comparisons and native tests, but increased production
source lines by 9, cyclomatic by 35, cognitive by 21 and effort by 101. The schema
checks were already explicit and had insufficient reuse to justify that split.
The experiment was reverted before this commit; its ignored patch remains evidence.

## 3. Unify structured-IP separator deletion

The largest handwritten function, `IpEdit.replace`, duplicated the backward and
forward fixed-separator deletion paths. Select the adjacent nonempty slot once,
then share range/index calculation and rejection. Reuse the chosen slot identity
instead of scanning the list again. Express the auto-advance single-character guard
as one length comparison. TypeScript remains the source of truth; regenerate JS.

This deliberately small change preserves whole-value paste rejection, malformed
source recovery, local selection/undo and per-slot limits rather than inventing a
new edit dispatcher. The function improves **36/44/192 → 35/41/179** (cyclomatic /
cognitive / effort). Production source and physical lines each fall **7**; the
remaining high complexity still merits review, not a claim that the hotspot is solved.

Validation: **450** independent editor checks, native structured editor **16 passes**,
Wi-Fi IP suite **8 passes**, strict lint and TypeScript typecheck. New vectors cover
both directions across empty slots and IPv6 slashes, including no adjacent digit.
**143104** frozen old/new edit-operation comparisons pass. No interaction or backend
boundary changes; native arrows, deferred saves and rollback retain their contract.

## 4. Separate routine-run boundaries from group projection

Updates grouping now names its contiguous-span and group-anchor computations.
The span calculates the first local date once; group membership uses one Set and
one remembered-anchor search instead of repeated linear membership tests and a
second expansion scan. Remembered ID order still wins over chronological order,
and the selected group/individual run keeps its prior precedence. No requests,
inferred history outside the loaded window, or selection side effects are added.

`project` improves **15/24/87 → 6/8/38**; the new span/group helpers are **6/5/25**
and **5/4/23**. Production cognitive sum falls **7** and weighted effort **1**;
cyclomatic sum rises **2** for the added functions, and source/physical lines rise
**11/13**. This is a bounded algorithm/readability tradeoff, not a runtime benchmark
or LOC win. Locality/leverage scores are unchanged.

Validation: strict lint, Updates native suite **26 passes**, and **12000** frozen
projections comparing complete old/new row structures. New native-JS vectors cover
local-day and lane boundaries, remembered-anchor order and selected-run expansion;
the existing native key/menu/refresh test covers real consumer fold/unfold behavior.

## 5. Isolate notification preview rendering

Extract `NotificationPreviewCard` from the heavily coupled timeline delegate. Its
inputs are a projected entry, clock and delete availability; its outputs are
expansion/deletion intents. It cannot read or mutate the timeline/controller.
`NotificationIndex` retains the window, scrolling, stack-state mutation and guarded
record deletion. The surrounding CommandGroup still owns command scope; plain-text
rendering, stable object names, translation contexts and shared card/button
composition are preserved. This is domain content, not a new settings wrapper.

NotificationIndex locality improves **0 → 31**, objects **23 → 16**, component
fan-out **10 → 8**. The leaf has locality **77** and one referenced ID. Production
mean locality improves **74.2078 → 74.3093**. Costs: **15** source / **19** physical
lines, **2** cyclomatic and **4** effort for the explicit signal boundary; mean
leverage falls **36.4608 → 36.3964** because this leaf has only one consumer.

Validation: strict lint and NotificationCenter **5 passes**. The new actual-page
pointer/key regression expands a native stack, deletes a specific expanded member,
checks its exact record identity and disabled repeat command, and verifies that
previews add no editable Tab stops or application-selection side effects. Existing
native consent/cancel/no-replay and timeline rejection tests remain intact.

## Combined results and acceptance limits

| Metric | Production before → after | All analyzed sources before → after |
| --- | ---: | ---: |
| Source lines | 43552 → 43541 | 50263 → 50335 |
| Physical lines | 48411 → 48407 | 55331 → 55410 |
| Cyclomatic sum | 9249 → 9247 | 9903 → 9902 |
| Cognitive sum | 6591 → 6577 | 6851 → 6839 |
| Weighted function effort | 45082 → 45047 | 50022 → 50050 |
| Mean locality | 74.1777 → 74.3093 | 75.5558 → 75.6606 |
| Mean leverage | 36.2801 → 36.3964 | 32.6234 → 32.7332 |
| Normalized clone groups | 111 → 112 | 152 → 153 |
| Clone-covered lines | 1542 → 1554 | 2095 → 2096 |
| `property var` | 523 → 522 | 560 → 559 |

Both clone scans are complete with zero omitted windows/groups. Unknown-signal
escapes remain **0**, lint-disable occurrences **15**. Cleanup retains only the
intentional SystemTray enum test stub; parser diagnostics remain zero.
**This is not an across-the-board reduction:** production code shrinks slightly,
but added regression coverage raises tracked code (including tests/scripts/TS)
**64096 → 64177** physical lines. Full-scope effort and normalized cloning also
rise. The main gains are the typed shared boundary, less coupled notification
rendering and simpler live operations; not bulk deletion or a runtime speed claim.

Final checks: **207 Qt passes, 0 failures, 1 existing software-renderer skip**;
strict QML lint; both offscreen Quickshell smokes; TypeScript freshness/typecheck;
source-tree import check; UI drift review **0 prompts**; whitespace check.
Incoming edits compare byte-for-byte unchanged. No tests were removed or newly
skipped, no numeric style override was added, and no interaction/safety guard was
weakened. The offscreen window-mask warning remains. Static semantic coverage is
still partial; no full Lens audit pass, package/Nix build, sibling-daemon contract
campaign, profiler result, live hardware/compositor, IME or screen-reader acceptance
is claimed. Source-tree checks do not substitute for those release gates.
