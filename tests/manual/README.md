# Circular-action visual review

`tests/manual/tst_action_review.qml` loads all 12 actual registered surfaces with
synthetic data and recording transports. It checks visible command circles,
icon presence and nonvisual button labels, and captures normal/minimum geometry
in both themes, plus Activity/Bluetooth/Notifications subpages, prompts, toasts
and the compact bar. No real settings or actions are submitted.

```sh
mkdir -p target/circular-action-review
export FONTCONFIG_FILE=/path/to/packaged-fonts.conf
fc-match 'Roboto Flex'
fc-match 'Material Symbols Rounded'
tests/run-qmlquality-tests.sh -input tests/manual/tst_action_review.qml -o -,txt
```

The ignored PNGs are review artifacts, not golden tests. Shared unit geometry
cases additionally cover fractional and 2× layout scales. To inspect native
fractional/HiDPI rasterisation, repeat this fixture with `QT_SCALE_FACTOR=1.25`
or `2`. Live compositor, hardware modifiers and screen-reader acceptance remain
separate checks.

# Form-field visual review

`tests/manual/tst_form_review.qml` captures the shared field family and real
Wi-Fi IP/DNS pane, using synthetic values and the recording daemon boundary.
It never sends replies or applies network settings.

```sh
mkdir -p target/form-field-implementation
export FONTCONFIG_FILE=/path/to/packaged-fonts.conf
tests/run-qmlquality-tests.sh -input tests/manual/tst_form_review.qml -o -,txt
```

Eight PNGs cover light/dark shared fields, IPv4, IPv6 and narrow network forms.
Captures are ignored build artifacts, not golden tests. The fixture checks that
no backend mutation is emitted. Hardware IME, pointer-selection paste, compositor
scaling and screen-reader acceptance remain live checks.

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
