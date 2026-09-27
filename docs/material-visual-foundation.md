# Material visual foundation

This is step 2 of the [agreed design](proposals/material-expressive.md), not a
claim of a finished Material 3 Expressive interface.

## Color implementation

`Ui.MaterialPalette` is a Qt-only, reactive palette taking `seedColor` and `dark`.
It uses Google's **@material/material-color-utilities 0.4.0**, pinned by URL and
SHA-256 in `nix/material-colors.nix`. HCT/tonal generation is upstream color
science, not RGB interpolation presented as Material. The provisional scheme is
**Tonal Spot, spec 2021, standard contrast**. Expressive component styling does
not require using the differently named Expressive color-scheme variant.

Primary/secondary/tertiary, container, surface, outline and error roles come from
upstream. Success and warning are explicitly Shelllist extensions: HCT hue/chroma
145/36 and 85/36 with background/foreground tones 40/100 (light), 80/20 (dark).
All role colors are opaque. Seed alpha does not make controls translucent.

`tools/material-colors.mjs` is the authored adapter. The generated QML JavaScript
bundle and upstream Apache-2.0 license are checked in so a normal source checkout
requires no npm install or runtime dependency download. The Nix `materialColors`
check rebuilds and compares both artifacts, then tests WCAG contrast for 150
seed/mode combinations. Native Qt tests retain reference colors. Generated upstream source adds
code volume; it is not hand-maintained application logic.

Qt compatibility is tested with the actual QML engine, not only Node. The
adapter avoids `Object.fromEntries`, which Qt's JavaScript engine lacks. The
build explicitly hoists two already function-scoped `var` declarations to avoid
Qt forward-reference warnings; it preserves initialization order and does not
change upstream color calculations or suppress warnings. QML foreground properties
use `primaryText`, `surfaceText`, etc.: `onPrimary`-style property initializers
were silently interpreted as handlers by Qt. Exact QML foreground assertions and
rendered gallery inspection now cover that adapter failure, not just Node output.

To regenerate using current sibling worktrees:

```sh
python3 ../daemon-framework/tools/local-build.py build --attr materialColors . \
  --no-link --print-out-paths
# Copy MaterialColors.generated.js and material-color-utilities.LICENSE from
# the printed store directory into qml/Shelllist/Ui/ (make local copies writable).
node tests/check-material-colors.js qml/Shelllist/Ui/MaterialColors.generated.js
```

## Desktop theme integration

`Theme` now derives semantic tokens from this palette. `SystemPalette.accent`
supplies the seed unless `SHELLLIST_ACCENT` explicitly overrides it.
`Application.styleHints.colorScheme` supplies light/dark, with system-window
brightness as the fallback for an unknown platform preference. Bindings respond
to desktop palette and scheme notifications; there is no theme polling or daemon.
An environment seed override remains fixed for the process's environment.

Individual legacy background/text/status overrides are intentionally retired;
see the README migration note. Resource-series overrides remain independent.
Secondary text uses `onSurfaceVariant`, not progressively lower-contrast blends.
Action foregrounds use their matching `on…` role. Segmented selection uses a
solid secondary container and its matching text role; result-row details actions
use the regular primary/on-primary highlight pair rather than arbitrary blends.
Flat icon buttons bypass their decorative hover animation while focused, so the
focus foreground/ring immediately has the correct background even during an
in-flight hover transition or busy state. Existing token names remain as migration
aliases for domain views; this is not a wholesale component redesign.

The chooser shell uses a provisional **94% opacity**. Controls and selection
containers remain solid. Contrast tests include the composited shell over black
and white backgrounds. This adds transparency, **not compositor blur**; live blur
integration and visual validation remain separate work.

## Expressive buttons and switches

Shared `ActionButton` (including `FlatIconButton`) now rests as a capsule/circle
and morphs to an **8px pressed corner**, bounded by the available size. This
follows the small Expressive button's full/CornerSmall shape pairing. Existing
42px desktop control height is retained rather than resizing every consumer to
the 40px mobile button token. Width, height, hit regions and text never animate.
The old unbounded button ripple is replaced by solid state color and shape
feedback; other `StateLayer` consumers are unchanged.

Both switch presentations share a **52×32** track, **16px off / 24px on** thumb
and **28px pressed** thumb. Off uses a solid surface-container fill with a 2px
outline; on uses primary with its paired foreground. Tone-specific rows retain
matching foregrounds. Toggle rows now reserve a full 42px control height, and
standalone switches have a 64px-wide hit region. Explicitly constrained switch
sizes fit their parent; normal desktop/laptop layouts do not reduce these sizes.
`SHELLLIST_RADIUS` continues to affect legacy fields/cards/surfaces, not these
component-specific button/switch shapes.

`ExpressiveMotion` is a small Qt-only numeric spring shared by radius, thumb
position and thumb size. Qt parameters (spring 4.5, damping 0.8) are provisional
control tuning, not a claim to implement Material's physics constants. New
input retargets the running spring rather than queuing transitions. Pointer and
keyboard press feedback share the same visual state; keyboard activation still
occurs immediately on key-down, with no auto-repeat activation. Release, focus
loss or becoming busy clears held-key decoration. Switch `checked` and
accessibility state follow the authoritative value immediately; decoration does
not acknowledge settings or dispatch operations.

Focus rings are never animated between controls. The existing flat-button
foreground/background bypass remains intact. Setting `Theme.noAnimations` to
true immediately stops the new springs at their latest target, including a
spring already running. In
Qt 6.11.1, disabling `Behavior` alone does not stop an active spring, and spring
duration is unbounded. The helper writes its owned scalar *after the Behavior
itself becomes disabled*, avoiding binding-update ordering races; re-enabling
motion does not replay old targets. Existing environment/default motion policy
is unchanged; desktop reduced-motion integration remains open.

Reference implementations checked for this slice:
[Material small button tokens](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/ButtonSmallTokens.kt),
[Material switch tokens](https://github.com/material-components/material-web/blob/main/tokens/versions/v0_192/_md-comp-switch.scss),
and [Qt SpringAnimation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html).
The installed Qt 6.11.1 types and corresponding Behavior/SpringAnimation
implementation were checked as well. This is an incremental desktop adaptation,
not full Material conformance or completed control-system migration.

## Material sliders and segmented choices

`ValueSlider` keeps Qt's native `Controls.Slider` as the input/accessibility
boundary. Its new paint uses **16px split tracks**, **4×44px handles**, rounded
outer ends, smaller inner corners and 4px endpoint markers. A 6px gap is reserved
around the fixed handle footprint. Active/inactive tracks use primary and
secondary-container roles. The default horizontal control is now 44px high;
vertical geometry is transposed and horizontal mirroring follows Qt's visual
position. Existing labels and explicit value readouts remain; no hover/focus
value bubbles were introduced.

Handle *position* and track fill follow the native value immediately, whether
changed by dragging, keys or authoritative state. Only the painted handle
thickness springs from 4px to 2px under focus/press; its native footprint stays
fixed, so decoration cannot change drag mapping. The shared inset focus ring
also appears immediately. The previous animated keyboard-position test was a
constraint on the wrong behavior and is now replaced with immediate-position
assertions. Home/End, stepped keyboard edits, live edits and completion signals
retain their existing contract.

`SegmentedControl` now has a solid, outlined capsule with joined options,
secondary-container selection and its paired text color. Selection fill, text,
accessible checked state and the selected option's inset focus ring update
together. There is no sliding background behind text that already changed
foreground. A group remains one Tab stop; Left/Right skip unavailable options
and follow the mirrored visual order. Options expose named radio-button states
and guarded assistive press/toggle actions. Becoming busy preserves current
focus; disabled/busy controls cannot dispatch through direct or assistive paths.
A group with no selected value retains a visible group-level focus ring.

The group uses the existing 42px desktop action height rather than the 40px
Material token, and 14px option labels instead of the old 12px labels. A separate
selected check glyph is omitted to preserve room for identifying option text in
compact settings rows; selected color/weight and nonvisual checked state remain.
End-cap shapes no longer depend on the legacy radius override. These component
changes do **not** implement the future region traversal/browse-versus-edit model.

Reference implementations checked:
[Material slider tokens](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/SliderTokens.kt)
and [outlined segmented-button tokens](https://github.com/androidx/androidx/blob/androidx-main/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/OutlinedSegmentedButtonTokens.kt).
Per-corner Rectangle radii are supported by the packaged Qt 6.11.1 and were
validated in the actual engine, including the software-rendered gallery.

## Development gallery

```sh
python3 ../daemon-framework/tools/local-build.py run --attr materialGallery .
```

The separate gallery uses the shared production controls. It shows light/dark
swatches for the desktop, purple and teal seeds; real controls with keyboard
focus, capsule button shapes and on/off/disabled Material switches; and
**Roboto Flex versus Noto Sans** samples. Hold Space or the pointer on a button
to inspect its press shape. The slider samples include live, disabled, mirrored
and vertical states; the segmented group includes an unavailable choice.
Its package supplies these fonts, and the offscreen check verifies both are available. The gallery does not
choose a production font or change system font configuration. Icon-family
comparison is still pending; current Nerd Font glyphs are retained.

Light/dark buttons set only the gallery process's `Theme.previewColorScheme`.
“Follow desktop” clears that local override. This explicit preview input is
needed because offscreen Qt platforms can ignore requests to change their
reported desktop preference. The resident host never sets this override. The gallery has no domain controllers,
daemon connections, resident-host registration or automatic help/tooltip UI.
It is not copied into `shelllistConfig` or started with the resident host.

For an offscreen image, set `QT_QPA_PLATFORM=offscreen`,
`QT_QUICK_BACKEND=software`, `SHELLLIST_GALLERY_SMOKE=1` and
`SHELLLIST_GALLERY_CAPTURE=/absolute/path/gallery.png` before the command above.
Set `SHELLLIST_GALLERY_SCHEME=light` or `dark` to choose the preview mode.
The capture mode uses a taller viewport and exits after saving. The Nix
`materialGallery` check launches both modes offscreen, verifies the mode and
fonts, rejects warnings and errors, and exits without deploying or restarting
anything.

## Validation checkpoints

The original palette/gallery slice passed strict lint, **210 Qt passes**
(including lifecycle hooks), the generated-color
reproducibility/contrast check, both offscreen gallery modes, shared-UI smoke
and the full sibling-aware `local-build.py check . --keep-going
--print-build-logs` gate. Offscreen light/dark captures were inspected;
local samples are `/tmp/shelllist-material-{light,dark}.png`. No live deployment,
compositor blur, hardware latency or screen-reader acceptance was performed.

The subsequent button/switch slice passed strict lint, **110 Qt behavioral
cases / 178 passes including hooks**, runtime smoke and the full sibling-aware
gate. Two new shared-boundary tests cover immediate activation/focus through
press/reversal/busy transitions and stopping running springs when motion is
disabled. The native domain recovery tests remain intact. Light/dark offscreen
captures were inspected at `/tmp/shelllist-expressive-{light,dark}.png`; detailed
logs are `/tmp/shelllist-expressive-controls-tests.log` and
`/tmp/shelllist-expressive-controls-full-check.log`.

The settings-control slice passes strict lint, **114 Qt behavioral cases / 182
passes including hooks**, runtime smoke and the full sibling-aware gate. Tests
exercise actual Qt input in horizontal, mirrored and vertical sliders, immediate
feedback, segmented radio semantics, skipped unavailable options and busy/disabled
activation guards. Existing domain recovery tests remain intact. Light/dark
captures were inspected at `/tmp/shelllist-material-settings-{light,dark}.png`;
logs are `/tmp/shelllist-material-settings-tests.log` and
`/tmp/shelllist-material-settings-full-check.log`. No live deployment, compositor
or screen-reader acceptance was performed.

Typeface/icon selection, broader shape/motion migration and final spring tuning,
compositor blur and real-desktop visual acceptance remain open. Contrast
calculations are evidence about color pairs and compositing, not a substitute for
checking every rendered
text treatment, disabled state or live blur.
