# Lens review: shared chooser cleanup

Baseline: `c6451f8f`, including five incoming modified files, preserved byte-for-byte.
Analyzer: local `../qmlqualitylens`, revision `6868f2f`. Evidence, source archive,
configs, complete-clone adapter and summaries: `target/lens-refactor-review/`.

## Decisions

- `ChooserListPane` / `ChooserListBody`: replace redundant forwarding properties
  and bindings with aliases to their existing owners. No new control family or
  state owner. Pane locality rises **19 → 46**, body **69 → 78**; their component
  effort falls **186 → 160** and **96 → 86**. Defaults and transformed status
  fallback remain at their original owners. Existing callers retain the same API.
- `ResultListFrame`: one two-instance passive fade delegate replaces duplicate
  top/bottom composition, retaining geometry, colours and animation.
- `NotificationIconSource`: separate candidate resolution from candidate priority.
  `resolve` cognitive/cyclomatic **24/17 → 10/10**; the new candidate helper is
  **7/8**. Combined cognitive decreases, combined cyclomatic increases by one.
  Resolve Halstead effort **19,474 → 9,059**, helper **5,147**; these are individual
  token metrics, not engineering hours or an aggregate Halstead calculation.
- Remove unused `BarTrayItem` and `PanelMessage` exports, the former's unused
  `Quickshell.Widgets` test module, and two unused IDs. Repository/sibling source
  and export searches found no consumers; Tray still uses its chooser. Keep the
  flagged `Status.qml`: `SystemTrayItem.qml` consumes its enum despite Lens's
  reachability warning. No safety/recovery handlers or tests were deleted.
- Two redundant `property var` declarations disappear (**477 → 475** production),
  replaced by aliases, not invented protocol types. Actual list models still
  legitimately support arrays and Qt models. Aliases increase **109 → 150**,
  introducing two unsuppressed `qml.alias_leakage` reviews. These aliases preserve
  existing value-level APIs, exposing no child objects or new writable properties.
  Shared UI review rationale: direct ownership replaces redundant forwarding state.
  Lint disables stay **15**; unknown-signal escapes stay **0**. No suppressions,
  discovery exclusions, tool thresholds or generated sources changed.

## Measurements

Production excludes only `tests/` and `dev/` from configured discovery; generated
JavaScript remains included. All includes both. Effort is Lens's heuristic effort;
locality/leverage are advisory component means, not correctness or productivity.

| Metric | Production before → after | All before → after |
| --- | ---: | ---: |
| Physical LOC | 44,950 → 44,817 | 57,975 → 57,879 |
| Source LOC | 40,308 → 40,183 | 52,971 → 52,884 |
| Cyclomatic sum | 8,036 → 8,017 | 9,423 → 9,408 |
| Cognitive sum | 5,530 → 5,508 | 6,275 → 6,253 |
| Function effort | 39,839 → 39,752 | 50,589 → 50,541 |
| Component effort | 45,826 → 45,654 | 61,005 → 60,868 |
| Mean locality | 75.7321 → 75.7429 | 77.4121 → 77.3696 |
| Mean leverage | 38.1464 → 38.2915 | 32.0603 → 32.1899 |
| Normalized clone groups | 108 → 106 | 179 → 177 |
| Clone-covered lines | 1,501 → 1,473 | 2,483 → 2,455 |
| Bindings | 11,604 → 11,521 | 13,132 → 13,046 |

Full-scope locality slightly worsens; production gains are modest, and means also
change with deleted components. Do not present this as a broad architecture win.
Clone comparison uses 200,000 keys / 1,000 windows per key / 10,000 groups, with
**zero omitted windows/groups** on both snapshots. Production projects those
complete groups onto production instances, retaining groups with at least two.
Default scans remain partial (100 normalized groups); those capped counts are not
used for the comparison. Cleanup reviews **6 → 1**, not proof of dead-code freedom.
No approximate function complexity records; overall maintainability remains **82**.

## Validation and remaining work

- Strict `tests/run-qmllint.sh`: pass. Full native suite with
  `QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh`: **849 → 859 passes**, zero
  failures, one unchanged renderer skip. Added candidate-order and scroll-edge
  cases; exercised refresh guarding through the aliased native button.
- All 17 JavaScript checks with their `flake.nix` arguments: pass (imports checked
  against the source tree, not a package). Native runtime smoke: pass, with the
  offscreen platform's unsupported-window-mask warning. Panel drift review: zero
  prompts. Incoming-file hashes and `git diff --check`: pass.
- Initial full-test attempt lacked local-XHR permission; the corrected complete
  run above supersedes it. An initial JS loop omitted required arguments; rerun
  with explicit arguments passes. Neither failed invocation is passing evidence.
- Static `measure all` / `audit` use separate before/after configs with execution
  and imported reports disabled. Audit remains **incomplete**, with semantic
  abstentions and partial default cloning; separate native passes do not make
  those static capabilities complete. Raw artifacts retain those limitations.
- Highest remaining owners include `NotificationBackend.finish`, clipboard commit
  recovery, `ChooserSession.apply`, display policy and Wi-Fi status reconciliation.
  Their request identity, acknowledgement and retry branches require dedicated
  domain evidence before further simplification. Generated colour algorithms and
  similar-looking option tables were not refactored merely to lower scores.
  No full Nix/package build, hardware mutation, IME or screen-reader acceptance.
