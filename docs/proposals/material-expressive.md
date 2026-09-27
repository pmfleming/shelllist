# Keyboard-first Material 3 Expressive: agreed design and implementation plan

Status: design decisions accepted through the owner interview; implementation is incremental. This document describes the **target**, not a claim that every rule is implemented. The implementation ledger below records delivered slices. It supersedes the earlier proposal wherever they differ.

## 1. Purpose and authority

Shelllist is primarily for its owner's daily desktop, as keyboard-operated as possible. It is not being designed around onboarding a general audience.

Priority order:

1. Visual polish and a distinctive, recognizably **Material 3 Expressive** appearance.
2. One coherent design and interaction system across surfaces.
3. Complete, predictable keyboard workflows.

Material's visual discipline is a constraint, not merely inspiration. Departures require a concrete usability reason. Existing layouts, bindings, components, configuration conventions and APIs are not sacred: break compatibility where it obstructs these goals. Data integrity, valid backend operations and safe system-action handling remain requirements.

Use visuals rather than prose. Text is appropriate only where it conveys necessary information that the visual treatment cannot: for example identifiable result names, editable content, precise time/date, or a meaningful error. Do not infer that all existing text is necessary.

## 2. Visual language

| Area | Agreed direction |
| --- | --- |
| Color source | Generate a coherent Material scheme from the **desktop accent**; do not blindly inherit every desktop palette color. |
| Light/dark | Follow the desktop automatically. |
| Surface | Blurred, translucent outer popover shell; solid Material controls and sufficient containment for predictable contrast. |
| Typeface | Dedicated Material-oriented typeface, not the desktop font. Exact family awaits visual samples. |
| Density | Deliberate contrast: relatively compact results/repeated data; more breathing room for settings, details and primary actions. |
| Actions | Primarily icon-only. No automatic labels on focus or hover. |
| Status | Pictorial states rather than battery percentages or notification counts in the bar. Exact data can be read in the corresponding surface. |
| Time/date | Readable numerical information is an explicit exception to the text-minimal rule. Exact formatting remains to be chosen. |
| Hover | Subtle visual state feedback only. **No hover tooltips anywhere**, including charts, controls and tray presentation owned by Shelllist. |
| Help | **No F1 help, contextual-help overlay, or automatic explanatory labels.** No replacement help shortcut is requested. Accessibility names remain nonvisual metadata. |
| Motion | Expressive, spring-like transitions and control feedback. Interruptible; never delay input, activation or logical state. |
| Focus motion | Focus indication snaps immediately to its target. Supporting decoration may animate, but must not trail or obscure the actual keyboard target. |

Necessary information must not disappear with tooltips. Move any essential explanation/value into an explicit details view, error state or required-input dialog, not another automatic popup. Do not manufacture meaningless icons to remove essential text.

## 3. Shared popover geometry

Shelllist stays a focused popover, not a large-screen dashboard.

Large screens and laptops use the **same split layout and navigation model**. A laptop tightens margins, padding and gaps; it does not automatically shrink text/control heights or replace results with details. Secondary text may truncate where necessary.

The earlier suggestion to replace results with details on narrow screens was explicitly superseded during the interview.

```text
Closed                              Details explicitly requested
       ┌────────────┐                      ┌────────────┬──────────────────┐
       │ Results    │           →          │ Results    │ Details          │
       │            │                      │            │ [tab] tab tab    │
       └────────────┘                      └────────────┴──────────────────┘
       Same left edge                      List stays anchored
```

- Use one shared placement rule for all lists.
- Initial list may be left of center, but keep it as close to center as practical while reserving space for rightward expansion.
- The reserved area remains normal desktop, not an empty rendered panel or input-intercepting window region.
- Details expand to the right; do not recenter/move the original list.
- List height is stable through search, filtering and live updates. Adapt the frame to the work area, not result count.
- Rich details use multiple tabs. Keep the tab bar out of the Up/Down-addressable content sequence.
- Bounds/minimum supported logical work area and overflow handling still require a measured implementation decision. Do not silently restore the rejected single-pane laptop design or clip controls.

## 4. Keyboard model

The critical distinction is **browsing versus editing**. Right means “more information/functionality” while browsing. Inside an editor, arrows retain their normal editing meaning.

### Search and results

```text
Search:  Left/Right move the cursor
         Down enters results

Results: Up/Down move selection
         Up from first result returns to search
         Enter performs primary action
         Right explicitly opens/enters details
         Typing returns to search and continues the query at its saved cursor
```

- Search is an ordinary text editor; there is no mandatory Ctrl+L query-edit mode.
- Printable keys, including J/K, are search characters, not list navigation hotkeys.
- Typing from results preserves the existing query/cursor instead of replacing the query.
- Do not open first-time details merely because a result is selected. Per-item restoration is the deliberate exception described below.
- Most tasks should be achievable from the list alone: launch an app, connect headphones, etc. Details add information and extra functionality.

### Details and controls

- Opening new details places focus in the **content**, not on the tab selector.
- Up/Down browse the content. Ctrl+Tab cycles detail tabs.
- Tab cycles visible major regions: Search → Results → Details → Search. Shift+Tab reverses. It does not visit every control in the whole popover.
- Right on an editable setting enters its editor. Arrow browsing must not accidentally mutate settings.
- Simple settings edit **in place**, not in a separate editor screen.
- Sliders, switches and other controls remain visually present while browsing; they are not replaced by plain value summaries. Inactive editing does not mean the control looks disabled.
- Browse focus highlights the row; edit focus clearly identifies the active control.
- Ordinary setting changes apply while editing. Leaving the editor does not undo them. Retain appropriate coalescing, acknowledgement, pending/error handling and duplicate-request protection.
- Safety-critical preview/revert flows, including display configuration, are not converted into unsafe immediate commits.

### Exit and surface toggles

```text
Editor ── Escape → Details ── Escape → Results ── Escape → Desktop
```

- Escape retreats one level and restores the preceding selection/focus.
- Left backs out of details while browsing; inside an editor it edits normally.
- The invocation binding is a whole-surface toggle: Super+Space opens Applications and closes it again, even from details/an editor. This is different from Escape's one-level retreat.
- Invoking the surface again restores the prior ordinary query, selection, tab, scroll and editing focus, subject to current valid backend state.

### Modal required-input exception

Passwords, pairing codes and similar input required for an explicitly requested action use a focused Material dialog over the existing list. This is not unsolicited optional details.

- Focus the first input immediately.
- Inside dialogs, Tab/Shift+Tab traverse fields and buttons conventionally. This is an explicit exception to region-level Tab in the ordinary surface.
- Text arrows edit normally; no extra Right press before typing into each field.
- Enter submits when valid; Escape cancels and restores previous focus. Nested popup handling must still be safe.
- Closing the whole surface **cancels sensitive prompts and clears sensitive input**. Do not restore their credentials/dialogs on the next invocation or resurrect expired daemon requests.

## 5. Session and per-result UI memory

Each individual result has its own remembered presentation state, retained until the Shelllist process restarts. Memory is not just per surface.

```text
Headphones previously inspected → select again → restore its details/tab/scroll
Keyboard never inspected        → select       → list-only
Headphones                      → select again → restore its previous view
```

- Remember details-open state, active tab, scroll and editing location by stable result identity, not row index.
- Returning to an inspected item may reveal details without a new Right press: restoration of a prior explicit choice is intentional.
- **Restoring an item through list selection does not steal keyboard focus.** Keep focus in results; Right enters its remembered details/editor location. The next arrow must not accidentally adjust a remembered slider.
- Reopening the whole surface can restore ordinary focus exactly; this is distinct from browsing between results.
- Explicitly closing details changes the item's remembered open state.
- Do not reset view memory simply because the surface closes, selection changes or a daemon reconnects. Sensitive prompts are excluded.
- UI memory does not freeze telemetry, bypass capability validation, replay effects or preserve expired operation tokens. Missing-item/changed-capability fallbacks still need precise implementation contracts.

## 6. Outcomes, errors and pointer interaction

- Successful handoffs (launching an app, pasting elsewhere) close the popover.
- Successful in-place actions (connecting, changing a setting) leave it open with updated status.
- Ordinary failures are **inline**; do not steal focus or automatically open a recovery screen. Retrying and deeper inspection are explicit actions.
- Required input is handled by the modal exception above, not by disguising a prompt as an ordinary failure.
- Hover never selects a result, changes keyboard focus, or restores a different item's details. Clicking selects; primary pointer-action gestures beyond this remain to be specified where needed.
- Preserve mouse-wheel, touchpad and touch list behavior from the [list interaction contract](../list-interaction-contract.md).
- Icon-only presentation does not remove accessible roles, names, checked/selected state or values.

## 7. Bar and new keyboard destinations

The bar is for awareness and pointer access, not a new keyboard-focus mode. Keyboard actions go through direct shortcuts and dedicated lists.

- One continuous, softly rounded bar; grouping happens inside it, not through floating islands.
- Persistent groups, in the supplied priority order: **Workspaces, Media, Network, Bluetooth, Battery, Notifications, Tray, Clock/date**.
- Remove the separate **Focused application** and **Audio** groups, rather than merely collapsing them on laptops.
- Application awareness comes through workspaces. Audio remains accessible through shortcuts, OSD and its own list.
- Battery and notifications use pictorial states, not persistent percentages/counts. Clock/date remain readable numerical data.
- Provide separate **Audio, Media and Tray lists**, each with its own invocation shortcut and the common list/state model—not one combined Controls list.
- All essential bar/tray actions need an explicit keyboard route. Do not remove a route before its replacement exists.
- Detailed content/bindings of these new lists, urgent-state behavior, overflow priorities within groups, bar translucency and workspace presentation still need specification/prototype validation.

### Media

```text
[Artwork]   [Back]   [Play/Pause]   [Forward]
```

The labels above are schematic. The bar shows **artwork and icons, no persistent track/artist/player text**.

- Music: previous/next song.
- Podcasts and video: seek 30 seconds backward/forward. The interview interpreted 30 seconds symmetrically; no different backward interval was requested.
- Unknown content type: default to ±30-second seeking.
- Provide a mode override in Media details, remembered for that player. Preference lifetime/storage and reliable classification need a backend implementation decision.
- Use visibly different icons for track versus seek actions; never claim unsupported actions work.
- Follow the most recently started playback automatically until the user explicitly selects a player.
- An explicit selection pins the player until the user requests automatic selection again or that player exits.
- Progress presentation and the exact artwork-click gesture were not settled by the interview; do not interpret “art + controls” as approval for additional text or controls.

## 8. Engineering direction and remaining decisions

The following is an **implementation recommendation**, not an additional owner-approved product requirement:

- Evolve the existing shared controls inside the Shelllist repo first. Keep generic control/rendering logic free of new Quickshell/provider/daemon dependencies where practical.
- Extract an in-repo Qt-only `Shelllist.Controls` module only when it provides a real boundary. Do not start a separate external controls repository without another real consumer and a supported API/testing/packaging story.
- Do not put QML controls in `daemon-framework`. It owns Rust infrastructure/platform adapters; Shelllist owns presentation, navigation and transient view memory.
- Use Qt-backed inputs/templates where helpful. Do not reinvent IME, text selection, accessible activation or popup behavior to achieve a visual effect.
- Material-derived tonal generation needs a real supported color implementation, not approximate RGB blending advertised as Material color science. Test composited contrast over the translucent shell.
- Keep known safety, asynchronous ownership, daemon acknowledgement and stable-model behavior. Domain policy belongs to daemons even where new Audio/Media routes require protocol work.

Still open (not blockers for independent foundation work): exact typeface/icon family and assets; token values; blur/elevation strengths; animation tuning; minimum work area; monitor routing; tab-state and missing-item fallbacks; precise new surface contents/bindings; bar overflow/urgent-state rules; media classification/preference persistence; icon-only equivalents for specialized actions; nonvisual accessibility verification and reduced-motion integration. Resolve these through visual samples or focused technical work rather than inventing interview answers.

## 9. Implementation sequence

This replaces the compatibility-first sequence in the original proposal.

1. **Remove rejected affordances and establish focus foundations.** Eliminate hover tooltips, F1/automatic help and stale documentation; retain necessary accessible metadata and explicit information routes. Add shared, immediate visible focus with behavioral tests. Do not globally erase text before suitable icons/explicit detail routes exist.
2. **Material visual foundation.** Choose typeface/icon assets with samples; implement desktop-accent/light-dark semantic palette, typography, solid controls, translucent shell and interruptible motion. Build a development-only gallery, not a second production toolkit.
3. **Shared list/editor interaction.** Implement search/list key ownership, region Tab, content-first details, explicit in-place editing, dialog exceptions and safe toggle semantics. Exercise this in Applications and a settings-heavy surface.
4. **Per-item session memory and anchored geometry.** Stable identities, per-tab scroll/edit locations, non-focus-stealing restoration, stable height and one bounded left-of-center placement rule across laptop/large screen.
5. **Domain migration and outcomes.** Migrate Wi-Fi, Bluetooth, Clipboard, Displays, Battery, Activity, Notifications and Time & Weather; preserve required-input cancellation, drafts, async outcomes and safety previews.
6. **New lists and bar.** Deliver Audio/Media/Tray keyboard routes before removing old routes; implement the agreed continuous pictorial bar, media semantics/selection and numerical clock/date.
7. **Full acceptance.** Test real keyboard journeys, theme/geometry matrices, accessibility, GPU/compositor blur and performance. Remove transitional APIs once all consumers are migrated.

### Implementation ledger

- Design interview recorded and published in `bba757e` before implementation began.
- Foundation slice (`eaf7372`): removed hover tooltips and the F1/question-mark help overlay, its state and help-only shortcut wrapper. Nonvisual names/descriptions remain. Battery chart values now require explicit click/keyboard inspection rather than hover; Escape leaves that inspection before dismissing the surface.
- Shared `FocusRing` now provides immediate inset focus feedback for action controls, text fields, icon tiles and result rows. It has no animation or input handlers, does not change geometry, and leaves selection distinct from focus/hover.
- Validation: strict QML lint, all 201 Qt test passes (including lifecycle hooks), and offscreen shared-UI smoke pass in the current local-build development environment. Focus tests run with decorative animations enabled. The full `local-build.py check . --keep-going --print-build-logs` gate also passes, including the current sibling daemon packages, protocol contracts, packaging and deterministic performance checks. The first gate attempt hit the runner time limit during daemon compilation; the longer retry completed successfully. A stale cached dev shell initially lacked the SVG plugin; rerunning in the current environment resolved those unrelated asset failures. No live desktop deployment, live latency benchmark or compositor visual review was performed.
- Material color engine (`29a28d1`): added a Qt-only reactive palette backed by pinned Google Material Color Utilities 0.4.0 (Tonal Spot, spec 2021), with explicit success/warning extensions. The reproducible bundle includes its upstream license; no runtime npm dependency. Reference vectors and contrast checks pass for 150 seed/mode combinations; strict lint and 206 Qt passes validate seed/mode changes in the actual QML engine. See [visual foundation](../material-visual-foundation.md) for generation and compatibility details. The following slice integrates it with Theme.
- Desktop palette/gallery slice: Theme now derives coherent semantic roles from the desktop accent (or explicit seed override), follows Qt's reported light/dark preference with a system-palette fallback, keeps control/selection fills opaque and uses provisional 94% opacity only for the chooser shell. Legacy per-role color overrides are retired with a README migration note. Segmented selection and details-action highlights now use matching foreground/background roles. Flat-button keyboard focus bypasses in-flight decorative color animation. A Qt foreground-property naming issue found in rendered samples is fixed and regression-tested.
- Development-only gallery: packaged light/dark desktop/purple/teal swatches, real shared controls and Roboto Flex versus Noto Sans samples. Its preview mode is local and works on offscreen platforms without changing the desktop preference. This is not a production typeface decision or a second toolkit. The gallery never loads domain controllers or runs with the resident host.
- Validation: strict lint, 210 Qt passes (including hooks), 150 seed/mode contrast combinations, reproducible bundle/license checks, both gallery modes, shared-UI smoke and the full sibling-aware check pass. Offscreen light/dark captures were inspected. No live desktop deployment or compositor blur/performance acceptance was performed.
- Expressive button/switch slice: shared buttons now morph from full capsules/circles to bounded 8px pressed corners, while switches share Material 52×32 tracks and 16/24/28px off/on/pressed thumbs. Small Qt springs retarget decoration without changing hit geometry, focus, checked state or activation timing. Keyboard press decoration clears on release, focus loss and busy transitions. Button shape/state color replaces its unbounded ripple; other ripple consumers are unchanged. Legacy radius overrides no longer determine these component-specific shapes.
- The shared spring helper also snaps a running transition to its latest target when motion is disabled. Native tests caught and now cover Qt's Behavior binding-order edge case; simply disabling a running animation was insufficient. The gallery includes on/off/disabled switches and press-shape inspection. Typeface/icon choices and the existing default motion policy are unchanged.
- Validation: strict lint, 110 Qt behavioral cases / 178 passes including hooks, shared-UI smoke, inspected light/dark offscreen captures and the full sibling-aware gate pass. Two new feature regressions were added after the completed pruning checkpoint, not replaced by deleting unrelated coverage. No deployment, compositor blur or real-desktop motion/accessibility acceptance occurred.
- Material settings-control slice: shared sliders now use 16px split tracks, slim 44px handles, a 6px handle gap and endpoint markers. Native Qt still owns value mapping, touch/dragging and accessible slider operations, including mirrored and vertical layouts. Only handle thickness springs; position and focus update immediately. Segmented choices now use an outlined capsule with matched selected colors, immediate per-choice focus, radio accessibility and guarded assistive activation. Mirrored arrows follow visual order. This does not yet implement the planned browse-versus-edit keyboard model.
- Validation: strict lint, 114 Qt behavioral cases / 182 passes including hooks, runtime smoke, reviewed light/dark gallery captures and the full sibling-aware gate pass. The old slider test prescribing animated keyboard position was replaced by the agreed immediate-feedback contract. Three native mapping rows and one segmented accessibility/guard case were added; no unrelated tests were removed. No deployment or live compositor/accessibility acceptance occurred.
- Material field slice: text inputs and dropdowns share opaque outlined frames with 4px corners, 42px default height and immediate primary/error focus rings. TextInput still owns editing, selection, password echo and IME; embedded reveal/trailing actions now use guarded shared icon buttons. Dropdown menus have matched selected/highlighted color pairs and immediate focus without opacity transitions. Passive hover no longer changes the native keyboard highlight; displayed/selected values track the owner's value rather than an unacknowledged native candidate. No automatic labels or tooltips were added.
- Validation: strict lint, 116 Qt behavioral cases / 186 passes including hooks, runtime smoke and the full sibling-aware gate pass. Two new boundary tests cover editing/masking/action guards and native menu navigation/acknowledgement/cancellation. Light/dark gallery captures were reviewed with menus both open and closed; a gallery-only unequal-column layout issue was found and fixed. Native domain recovery tests are retained. No deployment, hardware IME or screen-reader acceptance occurred.
- Still pending: type/icon asset choice, blur, broader shape/motion migration and final spring tuning, broad icon-only migration, new keyboard/editor model, per-result memory/anchored geometry, and the new surfaces/bar. Do not mistake these foundation slices for the completed redesign.

## 10. Validation

Prefer executable behavior tests at shared boundaries, with representative domain recovery tests. Do not preserve contradictory snapshots just because the old design had them.

- Search cursor behavior versus result navigation; J/K/text ownership; query/cursor restoration; Up to search; region traversal; content-first detail focus; Ctrl+Tab; nested Escape and whole-surface toggles.
- Two result identities with different detail/tab/edit states; reorder/filter/remove/reconnect; restored visual state never redirects the next list key into a control.
- Browse versus edit; immediate/coalesced setting changes; inline failures; no duplicate activation; sensitive prompt cancellation and secret clearing.
- No hover tooltips, automatic labels or F1 help. Necessary information remains available explicitly and through nonvisual semantics.
- Both screen classes retain the split model, anchored left edge and stable list frame; larger text/long names do not produce clipped or unreachable controls.
- Desktop accent and light/dark changes, transparent composition, focus contrast, and reduced/no-motion end states. Text should meet 4.5:1 contrast (3:1 for large text), with meaningful controls/focus distinguishable at 3:1.
- Keyboard-only routes for all bar actions; media type/capability fallback; pinned-player lifetime; no auto-focus stealing by the bar.

Run from Shelllist's development environment:

```sh
tests/run-qml-tests.sh
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
tests/run-performance-benchmarks.sh
tests/check-sibling-boundary.sh
```

Use the current [quality gate documentation](../qml-quality-review.md). New files must be included in the tracked local-build snapshot; do not validate against stale sibling pins. Record pre-existing failures, never relax checks to hide them. Live resident/responsiveness measurements are deliberate session tests, not permission to restart/deploy services automatically.

## 11. References

- [Material 3](https://m3.material.io/)
- [Building with M3 Expressive](https://m3.material.io/blog/building-with-m3-expressive)
- [Google Design: research behind Expressive](https://design.google/library/expressive-material-design-google-research)
- [Qt Quick Controls Material style](https://doc.qt.io/qt-6/qtquickcontrols-material.html)

Exact current component specifications and the packaged Qt version must be checked during implementation. Qt Material styling alone does not restyle Shelllist's custom Rectangles or establish full Expressive support. The desktop adaptations above are explicit product decisions, not a claim of formal Material conformance.
