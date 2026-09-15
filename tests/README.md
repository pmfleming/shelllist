# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables, compare helpers against themselves, or freeze visual
choices unless they are an explicit user-facing regression.

## Pruning inventory

Baseline: Shelllist commit `36e8a95`. This inventory supersedes the earlier
pruning snapshot; it does not count sibling daemon repositories.

Shelllist mixes ad-hoc JavaScript checks, QtTest, Rust and Python, so there is no
single runner-reported total. Using the reproducible inventory below:

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper call sites | 371 | 232 |
| Executed QML cases, including data rows | 92 | 76 |
| Rust test functions | 4 | 4 |
| Python test methods | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **474** | **319** |

That is a **32.7% net reduction**, not a coverage percentage or a count of
independent scenarios. QML excludes setup/cleanup; its full runner total is 124
passes, of which 48 are lifecycle hooks. Seventeen QML cases were removed; an
unrelated battery-tab regression was added concurrently and is included in the
final total. Existing tests were not merely combined or renamed to lower runner
totals. Redundant assertions within retained scenarios were also removed.

JavaScript counts line-leading assertion/helper calls using the fixed expression
below, including calls inside helpers and loops once per source site, not once
per invocation or data row. It is a syntactic inventory, not a count of every
failure guard. Packaging, build, lint, performance, generated-asset and module
checks remain enabled but are not counted as behavioral cases.

Reproduce the JavaScript numbers from the repository root:

```sh
python - <<'PY'
from pathlib import Path
import re
import subprocess

pattern = r'^\s*(?:assert\.\w+|expect|expectState|equal|near|ok|throws|compare)\('
for revision in ('36e8a95', None):
    if revision:
        names = subprocess.check_output(
            ['git', 'ls-tree', '-r', '--name-only', revision, 'tests'], text=True).splitlines()
        sources = [subprocess.check_output(['git', 'show', f'{revision}:{name}'], text=True)
                   for name in names if re.fullmatch(r'tests/check-.*\.js', name)
                   and not name.endswith('check-packaged-imports.js')]
    else:
        sources = [path.read_text() for path in Path('tests').glob('check-*.js')
                   if path.name != 'check-packaged-imports.js']
    print(revision or 'working tree', sum(len(re.findall(pattern, text, re.M)) for text in sources))
PY

tests/run-qml-tests.sh > /tmp/shelllist-qml-tests.txt
grep -c '^PASS.*::test_' /tmp/shelllist-qml-tests.txt
```

Rust has four `#[test]` functions in `rust/shelllist-search/src/lib.rs`; Python
has two methods in `tests/test_profile_qml.py`. The five daemon contract suites
are the `*DaemonContract` flake checks. Table/loop size reductions inside a QML
case, such as the Bluetooth layout matrix, do not reduce its inventory count.

## Removal decisions and remaining coverage owners

| Removed or reduced | Remaining owner / rationale |
| --- | --- |
| Fast Pair toggle/provisioning and noise-mode mutation UI tests | These controls were removed from the project UI. Read-only battery topology, mode artwork, unknown state and the requested icon/label alignment remain tested. Daemon contracts are unchanged. |
| Direct Bluetooth prompt-queue assertions and one-field response classification checks | `tst_bluetooth_recovery.qml` exercises concurrent prompts, retained input, failed replies, unavailable backends, live reconnects and opaque-key routing. Distinct display-progress, scan-failure and operation-terminal cases remain in the JS suite. |
| Provider execution-request serialization and layout-presentation constraints | `tst_provider_registry.qml` checks real dispatch, provider/result identity, context and disabled-action rejection. Model validation, cross-provider batches, asynchronous ranking and Rust search regressions remain. |
| Notification formatting, filter/merge duplicates and numeric preview capacities | `tst_notifications.qml` owns active/history filtering, multi-page catch-up, DND acknowledgement, pending/error replies, persistent drafts, live focus and narrow-height reachability. JS retains untrusted group keys, reused notification IDs, updates and monitor routing. |
| Battery selection internals, repeated forecast values and duplicate action allowlists | Controller tests retain actual saved values/target identity, abandoned edits, autosave failure/editing races, global operation exclusion, AC/cancellation rules and capability guards. Backend tests retain the power-action allowlist. History-card tests retain real limits/hover; JS retains invalid samples, discontinuities, charging outliers and energy integration. |
| Application history bookkeeping and repeated range changes | Retained tests cover target/range isolation, stale replies, cancellation, multi-page catch-up, sliding-window pruning, empty cursor retention, partial failures, overlapping pages and nonadvancing cursors. Chart tests retain supported zero readings and gaps for unavailable measurements. |
| Exact palette/header/typography/badge assertions, navigation-key lookup enumeration, redundant ActionArea checks and bar action-ID table mirrors | Keyboard activation, disabled controls, accessibility labels, visible list selection, intentional scrolling, essential bar reachability and immediate OSD feedback remain covered through consumers. These removals free incidental visual/composition choices, not protocol requirements. |
| Legacy network-health fallback messages and raw Wi-Fi flag precedence | Current daemon failure recommendations, suppression policy, successful/sleep traces, unknown actionable failures, captive portals and security distinctions remain covered. Health logging now uses an injected credential sentinel rather than checking for the word “password.” |
| Repeated geometry/ranking helper checks and resource capability booleans | Monitor transforms, workspace rules, snapshot parsing, bounds, real ranking outcomes, resource aggregation and actual chart segmentation remain covered. Current supported Hyprland dispatcher syntaxes are retained. |

The shared-session/transport suite is untouched: failed-generation effects must
never replay, incompatible events are rejected, gaps resynchronize, late
subscriptions are cancelled, detached owners cannot receive replies, and stale
generations cannot claim new requests. Wi-Fi secret submission, IP validation,
clipboard background annotation and revision-checked bulk deletion are also
unchanged. All Rust search and Python profiler tests are retained.

No production behavior, protocol fixture, generated binding, dependency lock,
security guard or quality threshold was changed by this pruning pass. The
concurrent battery-tab implementation and test changes were left untouched.

## Validation

Completed for this pass:

- All retained JavaScript suites and the QML/search flake checks pass.
- QtTest: **76 behavioral cases**, zero failures/skips (124 passes with hooks).
- `python tests/test_profile_qml.py`: **2 passed**.
- `git diff --check`: clean.
- `nix flake check --keep-going --no-update-lock-file`: all checks except two
  existing contract failures pass, including QML lint, packaging, generated
  assets/TypeScript, performance and module evaluation.

The two failures reproduce at the unmodified baseline `36e8a95`, with identical
Nix derivations:

- `btDaemonContract`: the locked daemon fixture lacks the already-checked-in
  `fast_pair_controls_enabled` policy field.
- `nmDaemonContract`: the checked-in `NmApi.js` differs from generated output
  in formatting.

Neither check was removed or weakened, and neither the fixtures nor the lock
were updated to hide the failures. Locked integration and candidate sibling
worktree integration remain separate concerns.

Recommended co-development commands, from the declared development environment:

```sh
tests/check-sibling-boundary.sh
python tests/test_profile_qml.py
tests/run-qml-tests.sh
```

The sibling gate overrides release pins with current local Git worktrees and
checks vendored snapshots before the full flake matrix. Tracked uncommitted
changes are included; Git-add new files first. It leaves locks and installed
services untouched. Run `nix flake check --keep-going --no-update-lock-file`
separately when validating reproducible release pins, not as a substitute for
current-sibling compatibility.
