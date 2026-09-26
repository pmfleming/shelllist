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
check rebuilds and compares both artifacts, then tests reference vectors and
WCAG contrast for 150 seed/mode combinations. Generated upstream source adds
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

## Development gallery

```sh
python3 ../daemon-framework/tools/local-build.py run --attr materialGallery .
```

The separate gallery uses the shared production controls. It shows light/dark
swatches for the desktop, purple and teal seeds; real controls with keyboard
focus; and **Roboto Flex versus Noto Sans** samples. Its package supplies these
fonts, and the offscreen check verifies both are available. The gallery does not
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

## Validation checkpoint

Strict lint, **210 Qt passes** (including lifecycle hooks), the generated-color
reproducibility/contrast check, both offscreen gallery modes, shared-UI smoke
and the full sibling-aware `local-build.py check . --keep-going
--print-build-logs` gate pass. Offscreen light/dark captures were inspected;
local samples are `/tmp/shelllist-material-{light,dark}.png`. No live deployment,
compositor blur, hardware latency or screen-reader acceptance was performed.

Typeface/icon selection, shape and spring tuning, compositor blur and
real-desktop visual acceptance remain open. Contrast calculations are evidence
about color pairs and compositing, not a substitute for checking every rendered
text treatment, disabled state or live blur.
