# Proposal: keyboard-first Material 3 Expressive

Status: proposed; no UI implementation changes in this document.

## Recommendation

Adopt **Material 3 Expressive principles, adapted to a keyboard-first desktop shell**, not a pixel-for-pixel Android interface. Build custom controls **inside the Shelllist repository first**, evolving the existing `Shelllist.Ui` controls. Establish a portable-controls boundary, but extract an external package only when a second real consumer justifies it.

The outcome should be a more legible, deliberate and responsive Shelllist: obvious keyboard focus, clear primary actions, stronger grouping, richer but controlled color, and motion that explains transitions. Preserve fast search, dense result lists, existing shortcuts and daemon ownership.

## 1. Starting point

Shelllist already has much of the foundation:

- `qml/Shelllist/Ui/Theme.qml`: centralized colors, typography, geometry, density and motion; authoritative environment overrides with `SystemPalette` fallback.
- `ActionControl.qml`: shared Return/Enter/Space and accessibility activation, including busy-focus retention and duplicate-activation protection.
- `StateLayer.qml`, `Elevation.qml`, `InteractiveBehavior.qml`: shared feedback, depth and motion, with an existing `Theme.noAnimations` policy.
- `ActionButton`, `FlatIconButton`, `ToggleSwitch`, `TextField`, `ValueSlider`, `DropDownList` and `SegmentedControl`: existing custom or Qt-backed controls to evolve rather than duplicate.
- `ResultRow`, `ResultNavigation`, `ChooserShortcuts`, `DetailsTabBar`, `ScrollableListView`: established chooser behavior.
- Behavioral Qt tests, strict lint, runtime smoke, packaging checks and resident/responsiveness benchmarks.

Specific improvement opportunities visible in the code:

- Focus styling is distributed across controls and often a one-pixel border. Selection, hover and focus can look similar.
- `StateLayer` gets its pressed/ripple feedback from pointer input; keyboard activation does not have equivalent shared feedback.
- Theme colors are mostly blends of a small palette rather than explicit surface/container/on-color roles. `Theme.luminance()` is not a WCAG contrast calculation.
- Most shapes derive from one radius. There is little distinction between action emphasis, grouped controls and surface hierarchy.
- Existing semantic actions and recovery behavior must survive visual changes; a visual redesign is not permission to change acknowledgement or draft semantics.

## 2. What to adopt—and what not to adopt

| Expressive idea | Shelllist application | Guardrail |
| --- | --- | --- |
| Color and contrast guide attention | Tonal selected rows, differentiated containers, a clear primary action | Selection, focus, success and error must remain distinct; never rely on color alone |
| Shape communicates relationships | Coherent grouped settings, related button groups, stronger selected-segment shape | Do not turn every row into a large pill or nest cards unnecessarily |
| Typography establishes hierarchy | Clear surface title, section heading, body, supporting text and shortcut roles | Keep dense results; preserve font overrides and test larger text |
| Size communicates importance | Emphasize the next meaningful action, such as Connect or Preview changes | No oversized mobile-style actions that displace useful results |
| Motion explains change | Short detail transitions, selection feedback, expand/collapse and progress | State and activation are immediate; no waiting for animations |
| Containment makes structure readable | Group related settings and separate editable state from observed information | Preserve predictable layout and navigation order |

Do not add a floating action button, bottom navigation, gesture-only actions, decorative bouncing lists or a constantly animated bar merely to resemble Material examples. Keep the 51 px bar and current list density as the starting baseline. Use expression most strongly at the current selection, primary action and meaningful state change; keep surrounding content calm.

Keep Noto Sans and current icon compatibility initially. Evaluate Material Symbols separately for legibility, fallback and packaging; do not bundle an icon/font migration into control behavior changes. Wallpaper-derived dynamic color is optional future work, not a prerequisite.

## 3. Where the custom controls belong

### Options

| Option | Benefits | Costs | Decision |
| --- | --- | --- | --- |
| Evolve `Shelllist.Ui` in this repo | Atomic changes with consumers/tests; existing Nix packaging; immediate real-world feedback | Generic controls can accumulate shell dependencies | **Start here**, with explicit boundaries |
| Separate QML module in the same repo | Enforced imports and standalone gallery; easier eventual extraction | Migration and theme-adapter work | Introduce when the pilot establishes a useful portable subset |
| External repo immediately | Independent releases and reuse | Premature API commitment, coordinated releases, Qt/import/package compatibility and additional co-development tooling | Not justified by the currently identified consumer |
| Apply Qt Quick Controls Material style globally | Useful existing Qt styling and behavior | Does not automatically restyle custom Rectangles or supply all desired Expressive behavior | Evaluate as a reference, not the migration strategy |

### Boundary to establish

The eventual portable subset should contain tokens/style data, focus indication, interaction feedback, labels, buttons, switches, fields, sliders, segmented controls and menus. It should depend on Qt Quick/Controls only, not Quickshell, daemon protocols or Shelllist provider types.

Keep these in Shelllist:

- Environment/system-theme resolution and existing `SHELLLIST_*` compatibility.
- Window hosting, compositor integration, monitor routing and surface shortcuts.
- Chooser navigation, provider/result models, `ResultRow`'s chooser integration and domain workflows.
- Action policy, asynchronous operation state, validation and draft/recovery ownership.

Today `Theme.qml` imports Quickshell, and `Shelllist.Ui` combines generic controls with chooser/window types. Moving that entire directory to another repo would export Shelllist coupling, not create a reusable toolkit.

During the pilot, evolve the existing files and keep portable rendering free of new shell dependencies. If the subset proves coherent, create `qml/Shelllist/Controls/` (`Shelllist.Controls`) in a separate, behavior-preserving change. Supply resolved style values through an explicit Qt-only style object; keep the environment/theme adapter in `Shelllist.Ui`. Controls emit user intent; consumers own application state. Compatibility wrappers are temporary API bridges, not a second independently implemented control set.

Use Qt-backed controls/templates where they reduce the burden of text input, IME, slider, popup and accessibility behavior. Preserve the existing tested `ActionControl` semantics unless a focused prototype proves a replacement equivalent. Avoid a blanket rewrite into either raw Rectangles or Qt templates.

### External extraction gate

Revisit an external repository only when:

1. A second independently deployed application needs the same controls.
2. That application can consume the subset without Shelllist/Quickshell/provider imports.
3. The API has survived use in the pilot and several Shelllist surfaces without consumer-specific flags.
4. A standalone gallery, keyboard/accessibility tests, supported Qt versions and Nix package exist.
5. Someone owns compatibility, releases, licensing and downstream upgrades.

Then move the Qt-only module with its tests, version its API, package its QML imports once, and extend local worktree/build tooling for co-development. Do not vendor a second copy. Independent version pinning belongs to reproducible releases, not stale local-development snapshots.

## 4. Keyboard and accessibility contract

Make this contract the acceptance criterion before visual work:

- Opening a chooser makes search usable immediately. Reopening preserves the existing logical selection and reveals it without resetting it.
- Preserve Up/Down, list-context J/K, Enter, Left/Right for details, Ctrl+Tab, surface switching, refresh and contextual help.
- Printable text belongs to the active editor. J/K, Space, `?`, arrow keys and IME composition must not be stolen by chooser shortcuts while editing.
- Tab/Shift+Tab traverse meaningful controls in a stable order. Composite lists and segmented controls use internal arrow navigation rather than requiring a Tab stop for every item; retain access to row secondary actions.
- Enter/Space activate focused controls once. Auto-repeat must not repeat destructive/system actions. Busy controls retain focus but reject duplicate activation.
- Sliders preserve arrows and Home/End, expose values accessibly, and keep existing edit/commit semantics. Visual feedback must not accidentally increase daemon writes.
- Escape closes the innermost popup/modal/details layer before the surface. Existing domain cancellation/revert rules take precedence, particularly display previews and credential prompts.
- Opening/closing details, menus and modals has explicit focus destinations and restoration. Restore by stable logical identity after model changes, with a deterministic fallback when the item disappears.
- No essential action or status explanation is hover-only. Show concise contextual shortcut hints and retain F1/help; do not add permanent hint clutter to every row.
- Keep keyboard focus visually distinct from selection, hover, pressed, checked, error and busy states. Selected results remain identifiable while focus is in search or details.
- Focus indicators must not be clipped by rounded containers, list bounds or modal overlays. Keyboard and assistive activation get equivalent immediate feedback without stealing focus.
- Audit accessible roles, names, checked/selected state, values, error descriptions and pending state. Verify real assistive-technology behavior on the supported Linux session; attached QML properties alone are not sufficient evidence.

This is keyboard-first, not keyboard-only. Preserve the [list interaction contract](../list-interaction-contract.md): native wheel/touchpad/touch scrolling, wheel pass-through and stable keyed delegates. Bar restyling must not cause the resident layer-shell window to steal keyboard focus; essential bar functions must remain available through existing keyboard-opened surfaces/shortcuts, and any gaps should be recorded explicitly.

## 5. Token and control design

### Tokens

Extend `Theme.qml` with semantic roles before replacing values throughout views:

- Color: primary/on-primary, primary-container/on-primary-container, secondary roles where needed, surface/container levels, on-surface/on-surface-variant, outline, error and Shelllist-specific success/warning.
- Interaction: focus ring color/width/inset, selected-container roles and separate hover/pressed/disabled state-layer values.
- Shape: a small set of surface, group, control and emphasized-action shapes; map existing radius configuration compatibly.
- Typography: semantic roles mapped initially to existing font settings; tune headings and supporting text without inflating every result row.
- Density: compact desktop default and a comfortable option, independent of typography where practical. Derive interactive target areas without overlap and preserve native touch operation.
- Motion: feedback, spatial transition and emphasis roles, with reduced/no-motion equivalents. Retain `SHELLLIST_NO_ANIMATIONS`; do not add another conflicting animation switch.

Keep old token names as migration aliases where possible. Existing environment overrides remain authoritative. Start with reviewed light/dark palettes and compatibility mappings; simple RGB blending is not a Material tonal-palette algorithm. If generated tonal palettes become necessary, evaluate Material Color Utilities and a supported integration separately rather than writing an approximate color-science implementation in QML.

Validate contrast using linearized sRGB relative luminance and actual composited backgrounds: target at least 4.5:1 for normal text, 3:1 for large text and 3:1 for meaningful control boundaries/focus indicators. Arbitrary user overrides cannot guarantee these ratios; preserve overrides and report/document problematic combinations rather than silently rewriting them.

### First control changes

1. Add a reusable focus indicator and integrate it into representative existing controls.
2. Extend shared interaction feedback to keyboard/assistive activation without duplicating activation paths or mixing persistent focus with transient press state.
3. Give buttons explicit emphasis variants (filled, tonal, outlined, text) separate from semantic tone (normal, danger, etc.). Keep signal contracts and shortcut labels.
4. Update search/text fields with clear focus/error states, persistent labels where needed and supporting/error text that does not depend on placeholders.
5. Improve result selection, secondary-action discoverability, segmented indicators and settings grouping.
6. Update switches, sliders, dropdowns and dialogs after shared keyboard behavior is proven.

Shape changes may animate inside fixed geometry; they must not move neighboring targets. Selection/focus state updates synchronously even when decoration interpolates. Prototype interruptible spring-like spatial motion only where useful and supported by the packaged Qt version; there is no need to reproduce Android animation internals. Reduced motion keeps all information and removes nonessential spatial effects, ripples and pulsing. Avoid adding per-row effects or idle animation work.

## 6. Phased delivery

### Phase 0 — establish evidence and interaction baseline

- Capture current Applications, a settings-heavy surface, a prompt, the bar and OSD in light/dark themes, narrow layouts and larger text.
- Record key sequences, visible-result count, focus destinations and cold/warm responsiveness for representative tasks.
- Inventory control variants, direct color/geometry usage and keyboard-only gaps. Produce an annotated before/after design for Applications and one settings panel.
- Build a small development-only control gallery with fake data, showing focused, selected, hovered, pressed, disabled, busy, invalid and long-label states. Keep it out of production startup.
- Compare existing-control evolution with a small Qt Material/Qt-template spike under Shelllist's actual Qt version. Verify focus, IME, imports, sizing and reduced motion before choosing implementations.

**Exit:** agreed visual direction, keyboard contract and baseline; no production behavior change.

### Phase 1 — tokens and interaction foundation

- Add semantic tokens with compatibility aliases and light/dark contrast tests.
- Implement shared focus indication and keyboard feedback using a button, field and result row as representatives.
- Extend existing activation/navigation tests for focus restoration, shortcut/editor conflicts and interrupted/reduced motion.
- Add gallery/theme matrix coverage and preserve current consumer APIs.

**Exit:** foundational controls pass keyboard, accessibility, theme and runtime checks; no domain/controller refactor.

### Phase 2 — Applications vertical slice

- Migrate the search header, result row, details tabs, primary/secondary actions and application settings.
- Use Applications to validate search density, live keyed updates, details transitions, busy actions and warm reopen behavior.
- Keep surface-specific composition opt-in until reviewed. Changes to shared primitives must be checked against all consumers even during the pilot.
- Compare task completion and key counts with the baseline; adjust rather than accepting regressions as the price of redesign.

**Exit:** a convincing end-to-end keyboard-first surface, with no extra mandatory key presses for established tasks and no measurable responsiveness regression beyond baseline noise.

### Phase 3 — settings and recovery workflows

- Migrate Wi-Fi and Bluetooth: toggles, dropdowns, fields, credential/pairing dialogs and acknowledged settings.
- Migrate Clipboard: editor, confirmations and failed-draft recovery.
- Migrate Displays and Battery: segmented controls, sliders, preview/revert, pending operations and grouped settings. Coordinate with concurrent Displays work rather than mixing changes.
- Preserve draft identity, acknowledgement, retry/discard and daemon write coalescing. Do not change daemon protocols to support styling.
- At this point, decide whether the proven generic subset warrants an in-repo `Shelllist.Controls` module; separation is a dedicated change, not a prerequisite for finishing the visual rollout.

**Exit:** keyboard-only completion of high-risk settings/recovery journeys and no policy/contract changes.

### Phase 4 — remaining surfaces and cleanup

- Apply the language to Activity, Notifications and Time & Weather, preserving reply drafts, calendar navigation and readable chart/status information.
- Restyle bar and OSD last: restrained surfaces, clear active states and bounded local motion; no new idle animation or frame-driven decoration.
- Remove obsolete token aliases/temporary compatibility paths only after consumers migrate. Update documentation, packaged imports and Lens dynamic-entry metadata where needed.

**Exit:** coherent UI across all surfaces, validated performance and one maintained implementation per control.

## 7. Validation and release criteria

Extend existing behavioral owners rather than adding a test for every visual wrapper:

- `tst_action_control.qml`, `tst_settings_controls.qml`, `tst_segmented_navigation.qml`: activation, disabled/busy state, focus, slider semantics and accessibility.
- `tst_provider_shortcuts.qml`, `tst_search_action.qml`, `tst_result_list_reactivation.qml`: shortcut scope, search, selection identity, navigation and warm reopen.
- Existing domain tests: prompts, clipboard failure recovery, notifications/replies, display preview/revert and battery settings.
- Add focused coverage for token contrast, focus-indicator visibility and reduced-motion end states. Review gallery screenshots rather than freezing every pixel of every screen.

Manual matrix: light/dark/custom themes, no animations, narrow outputs, multi-monitor/fractional scale, larger fonts, long labels, keyboard-only, mouse/touchpad/touch, and supported screen-reader integration. Test real GPU/compositor rendering as well as software/offscreen Qt tests.

Run from the Shelllist development environment:

```sh
tests/run-qml-tests.sh
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
tests/run-performance-benchmarks.sh
tests/check-sibling-boundary.sh
```

Follow the current [quality-gate documentation](../qml-quality-review.md) for worktree/new-file handling and reproducible release validation. Run `tests/benchmark-resident.py --duration 20 --check` with Shelllist hidden and `tests/benchmark-responsiveness.py --check` in a deliberate live-session test; the latter opens surfaces. Record baseline and post-change results on the same machine, plus sustained arrow navigation through a large result list. Never mask existing failures or loosen budgets to make the redesign pass.

Release criteria:

- Established keyboard tasks take no additional mandatory key presses; all new actions have keyboard access.
- Focus is visible, predictable and restored correctly; editing and IME are not intercepted by navigation shortcuts.
- Default themes meet the documented contrast targets; larger text and narrow layouts remain usable.
- Pointer scrolling, stable models, drafts, daemon acknowledgement and preview/revert behavior are unchanged.
- Existing performance budgets pass; no new idle timers/animation work, delayed activation or substantial loss of visible results.
- Reviewers can identify the current selection, focused control, primary action and pending/error state without relying on color alone.

## 8. Sources and interpretation

- [Material 3](https://m3.material.io/) and [Building with M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive): design-system direction and component guidance.
- [Google Design: the research behind Expressive](https://design.google/library/expressive-material-design-google-research): color, shape, size, motion and containment should improve usability; preserving familiar patterns and labels matters.
- [Qt Quick Controls Material style](https://doc.qt.io/qt-6/qtquickcontrols-material.html): existing Qt styling, including a dense desktop variant. Check the packaged Qt version; the online reference alone does not establish complete Expressive support.

The Material site is JavaScript-rendered; its detailed component specifications were not verified from the fetched HTML during this planning pass. Validate the current component specs/design kit in Phase 0 before assigning exact token values. The desktop adaptations and implementation choices above are Shelllist recommendations, not claims of Material conformance. Google's reported study results are not evidence of a speed improvement in Shelllist; measure the actual keyboard workflows.
