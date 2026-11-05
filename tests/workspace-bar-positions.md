# Numeric shortcuts follow workspace bar positions

2026-11-05. The live desktop had workspace IDs 1, 2, 3, 4, 5, 6 and 10.
Zen occupied the seventh bar target, ID 10. Journal evidence showed that the
earlier ID 7 belonged to an Okular launch and was no longer a live destination.
Hyprland logged both `workspace move 7` and `workspace focus 7`; key delivery
was working, but those commands addressed the absent internal ID.

Numeric bindings now execute `bar-daemon workspace focus|move <position>
--position`, with 0 supplying position 10. The CLI sends `workspace_position`;
the serialized owner resolves that one-based position using the same ordering
function as the bar projection. ID-based callers retain their existing meaning.
Removing an earlier bar entry shifts later shortcuts without renumbering IDs.

Empty manually created destinations stay in the bar until explicit close and
can be rematerialized by either positional command. Launch-created destinations
retain their existing automatic retirement and grace period. Internal workspace
IDs remain monotonic and are not recycled. A missing position never allocates.

Coverage includes:

- All ten rendered Lua focus/move pairs, including 0 selecting position 10,
  owner routing, nonrepeating commands and existing lifecycle bindings.
- Owner tests for seventh-position ID 10, tenth-position ID 50, shifted positions,
  retained absent compositor objects, foreign observed ownership, standard
  destinations on another monitor, invalid/missing positions and ambiguous
  selectors. Rejections leave allocation and compositor effects untouched.
- The existing opt-in private Hyprland/D-Bus journey with actual Qt clients now
  checks the published bar order, executes the positional CLI, moves/follows a
  Qt window through position 7 into ID 10, repeats after the destination becomes
  empty, closes an earlier entry and checks that position 6 then targets ID 10.
  Missing position 7 is rejected without allocating a spare workspace. Existing
  icon, window-replacement, explicit-close and cancellation scenarios remain.

Validation:

- All ten rendered Lua focus/move binding pairs passed registration checks.
- All 22 focused workspace owner tests and the CLI parsing test passed.
- Fresh daemon protocol/control output matched the checked-in fixtures. Generated
  JavaScript matched the producer schema, including acceptance of numeric
  `workspace_position` and rejection of a string selector.
- Private Hyprland 0.56.2 and real Qt clients: one journey passed, including the
  new positional scenarios and all five existing replacement/cancellation modes.
  Evidence: `/tmp/handoff-nV7KLA`; log: `/tmp/workspace-positions-native.log`.
- Rust all-target suite: 356 passed, zero failures, nine existing opt-in skips;
  the private Qt journey was run separately as recorded above. Log:
  `/tmp/workspace-positions-validation.log`.

- Strict all-target Clippy (`-D warnings`) and `cargo fmt --all --check`: passed
  in the pinned Nix development shell with `--no-write-lock-file`. The opt-in
  workspace feature was enabled for the native test and all-target checks.
  Log: `/tmp/workspace-positions-validation.log`.

Source commits: bar-daemon `242ac3d`; NixOS bindings/tests `756b940`. Shelllist's
generated protocol artifacts, contract updates and this evidence are committed
together. Pre-existing local bar-daemon manifest/README edits were left outside
these commits.

No production service restart, compositor reload or NixOS activation is part of
this implementation. Private Qt checks do not claim physical keyboard delivery
on the production desktop.
