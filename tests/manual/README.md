# Compact confirmation review and implementation

`docs/reviews/confirmation-review.html` is a self-contained, offline review:
23 actual Qt state captures grouped into 17 inventory items, proposed HTML
replacements, per-item comments/approval, browser-local autosave and JSON
export/import. Export decisions to share feedback; the HTML is not rewritten by
browser edits. The approved revision-2 proposal is preserved as a before-change
archive; its replacement illustrations are not implementation screenshots.
Revision 2 uses the corrected compact Clipboard target: one question, inline
right-hand Cancel/Approve controls, and no explanatory paragraph or repeated
labels. Its feedback namespace is separate from revision 1; the previous HTML
is preserved as `confirmation-review-v1.html` so old approvals cannot implicitly
approve revised designs.

Capture the implemented QML (light/dark, 23 states, 90 PNGs):

```sh
mkdir -p target/confirmation-implementation/captures
tests/run-qmlquality-tests.sh -input tests/manual/tst_confirmation_review.qml -o target/confirmation-implementation/captures.log,txt
```

`build-confirmation-review.py` is the historical proposal builder; it refuses to
overwrite the approved archive from implemented sources. Actual interaction tests
live in `tests/qml/tst_compact_confirmations.qml` and the Clipboard, Notifications,
Battery and Displays consumer suites.

The explicit fixture uses real registered panel components with synthetic data
and recording transports; it never accepts prompts or performs live mutations.
It captures Clipboard, Notifications, Bluetooth's seven pairing kinds and Forget,
Wi-Fi Forget variants, Battery safety reviews, Display trial/discard, and the
Applications empty states from the supplied reference. The builder embeds both
cropped dialogs and full panel context. Its `REFERENCE` path identifies the
user-supplied target image. After-change evidence lives in ignored
`target/confirmation-implementation/`; the archived proposal follows the existing
ignored `docs/reviews/` convention. Captures use synthetic snapshots only, not real
hardware mutations. Shared native tests additionally cover narrow/light/dark
question wrapping, same-row action placement, focus, validation and cancellation.

# Panel standardization acceptance

The current twelve-panel matrix, exceptions and evidence limits are in
`docs/panel-ui-standardization.md`. Use the three fixtures below after changing
shared roles; they capture actual QML, not the illustrative HTML proposal.
They include measured Resources at 976×600, long operation failures, pending
notification policy, narrow Wi-Fi errors, and guarded display trial/drag states.

```sh
mkdir -p target/{circular-action-review,form-field-implementation,display-settings-review}
# Run all three fixtures below, then preserve the checkpoint:
mkdir -p target/panel-standardization/phase4/{captures,forms,displays}
cp -a target/circular-action-review/. target/panel-standardization/phase4/captures/
cp -a target/form-field-implementation/. target/panel-standardization/phase4/forms/
cp -a target/display-settings-review/. target/panel-standardization/phase4/displays/
python3 tests/build-panel-gallery.py
```

Open `target/panel-standardization/phase4/gallery.html`. The generator also includes
optional `fractional/` and `wayland/` folders; preserve the ordinary capture set
before repeating a fixture with another renderer/scale. A missing baseline is
explicitly labeled, not silently replaced. Review numbers/wrappers introduced by
a PR with `python3 tests/review-panel-ui.py --base <ref>`, documenting intentional
exceptions instead of banning chart/calendar/map geometry.

# External-heading decision review

`docs/reviews/external-header-review.html` preserves the offline **before-change**
checklist and six embedded pictures from the all-panel audit. The decision was
**remove all six external headings**; this is now implemented. The audit table
explains excluded standalone headings and other repeated text. Original checkbox
semantics were checked = keep; unchecked = delete only the external heading.

Capture the current **after-change** sections with recording transports:

```sh
mkdir -p target/external-header-removal
export FONTCONFIG_FILE=/path/to/packaged-fonts.conf
tests/run-qmlquality-tests.sh -input tests/manual/tst_header_review.qml -o -,txt
```

The fixture checks all six removals, retained internal titles, no blank heading
gaps, information-only boundaries and reachable fields; it rejects backend
mutations. `tst_chooser_keyboard.qml` additionally exercises the actual application
range selector with Enter/arrows/Escape/Tab and all loading/retained status variants.
The HTML's images are historical and remain embedded. The original builder
`build-header-review.py` refuses to overwrite the archive from post-removal sources.

# Circular-action visual review

`tests/manual/tst_action_review.qml` loads 12 registered list/detail surfaces with
synthetic data and recording transports. Agenda replaces the retired Activity
seed and uses actual list/get bridge replies. It checks visible command circles,
icon presence and nonvisual button labels, and captures normal/minimum geometry
in both themes, plus Agenda/Bluetooth/Notifications subpages, prompts, toasts
and the compact bar. No real settings or actions are submitted.

Calendar's distinct grid/composition captures and measured fallback journeys are
owned by `tests/qml/tst_agenda_calendar.qml`; shared editor journeys and captures
are in `tests/qml/tst_agenda.qml`. See `tests/agenda-calendar-release.md` for the
combined release evidence. The generic list/detail fixture does not substitute
for Calendar's three-pane, W-width and hidden-grid acceptance.

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

Ten PNGs cover light/dark shared fields, IPv4, long IPv6, narrow network forms and long errors.
The family capture includes the shared `IpField`'s combined prefix and dotted-mask
notations, red-only invalid IPv4/IPv6 and locked automatic values. The actual Wi-Fi
pane uses one combined address/subnet field and address-only gateways. Native
transactions and narrow caret revelation are covered by `tst_ip_control.qml` and
`tst_ip_fields.qml`; captures alone do not prove editing behavior.
Captures are ignored build artifacts, not golden tests. The fixture checks that
no backend mutation is emitted. Hardware IME, pointer-selection paste, compositor
scaling and screen-reader acceptance remain live checks.

IP-control delivery checkpoint: the isolated staged change set (without unrelated
working-tree updates) passed strict QML lint, TypeScript generation/type checking,
106 legacy-parser checks, 436 structured-IP checks and the full Qt suite: **178
passed, 0 failed, 1 existing RHI-only artwork skip**. The offscreen form fixture
produced all ten images; invalid/dotted-mask, IPv4 and narrow long-IPv6 captures
were inspected. Shared runtime smoke passed separately (the offscreen platform
reports its existing window-mask limitation). No real Wi-Fi mutation, hardware
IME, external drag/drop or human screen-reader acceptance was attempted.

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

The fixture writes 42 PNGs to `target/display-settings-review/`: compact,
layout/drag, multiple/mirrored/disabled monitors, draft, Focus overview, categories, Diagnostics, contextual help,
narrow list/editor, short Focus, and the confirmation dialog, in light/dark.
It checks initial Revert focus and rejects daemon mutations; read-only snapshots
are allowed. Images are intentionally ignored build artifacts, not golden files.

Inspect both the supported split canvas and narrow horizontal-overflow states.
The layout map is pinned in the left pane and does not scroll vertically with
either list or details; the existing shared minimum-width canvas can still move
it offscreen during horizontal editor revelation. Hardware mode changes, live
compositor placement and screen-reader acceptance remain separate manual checks.
