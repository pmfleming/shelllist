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
change upstream color calculations or suppress warnings.

To regenerate using current sibling worktrees:

```sh
python3 ../daemon-framework/tools/local-build.py build --attr materialColors . \
  --no-link --print-out-paths
# Copy MaterialColors.generated.js and material-color-utilities.LICENSE from
# the printed store directory into qml/Shelllist/Ui/ (make local copies writable).
node tests/check-material-colors.js qml/Shelllist/Ui/MaterialColors.generated.js
```

The palette currently exists independently of `Theme`; desktop integration and
the development gallery are the next slice. Typeface/icon selection, shape and
spring tuning, compositor blur and real-desktop visual acceptance remain open.
Contrast calculations are evidence about color pairs and proposed compositing,
not a substitute for checking rendered text, disabled states or live blur.
