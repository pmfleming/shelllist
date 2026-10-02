# Display visual review

`tests/manual/tst_display_review.qml` is an explicitly invoked, non-mutating
QtTest capture fixture. It uses the recording daemon boundary, not running
services. It is outside the ordinary unit-suite discovery directory.

From the repository root, in the Nix development environment:

```sh
mkdir -p target/display-settings-review
# Use a Fontconfig configuration containing the packaged Roboto Flex,
# Material Symbols Rounded and JetBrainsMono Nerd Font families.
export FONTCONFIG_FILE=/path/to/packaged-fonts.conf
fc-match 'Roboto Flex'
fc-match 'Material Symbols Rounded'
tests/run-qmlquality-tests.sh -input tests/manual/tst_display_review.qml -o -,txt
```

The fixture writes 28 PNGs to `target/display-settings-review/`: compact,
layout, draft, Focus overview, four categories, Diagnostics, contextual help,
narrow list/editor, short Focus, and the confirmation dialog, in light/dark.
It checks initial Revert focus and rejects daemon mutations; read-only snapshots
are allowed. Images are intentionally ignored build artifacts, not golden files.

Inspect both the supported split canvas and narrow horizontal-overflow states.
The layout map is pinned in the left pane and does not scroll vertically with
either list or details; the existing shared minimum-width canvas can still move
it offscreen during horizontal editor revelation. Hardware mode changes, live
compositor placement and screen-reader acceptance remain separate manual checks.
