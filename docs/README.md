# Shelllist documentation

The repository README is the user-facing overview and installation guide. These documents define current frontend behavior and architecture; daemon implementation details remain authoritative in each sibling daemon repository.

| Document | Scope |
| --- | --- |
| [`activity.md`](activity.md) | Activity surface, notification grouping, monitor routing, and ownership |
| [`application-launcher.md`](application-launcher.md) | Launcher behavior, lifecycle, resources, and `app-daemon` boundary |
| [`bar-osd.md`](bar-osd.md) | Shared OSD descriptor, event sources, timeout policy, and extension rules |
| [`displays.md`](displays.md) | Dedicated Displays callout, layout workspace, keyboard controls and daemon-owned recovery |
| [`daemon-frontend-commonality.md`](daemon-frontend-commonality.md) | Common daemon endpoint, recovery, sequencing, and chooser integration contracts |
| [`material-visual-foundation.md`](material-visual-foundation.md) | Material palette, production typography/icons, compositor preferences and development gallery |
| [`material-bar.md`](material-bar.md) | Continuous bar, Audio/Media/Tray routes, daemon-owned media policy, prototype decisions and acceptance limits |
| [`chooser-session-memory.md`](chooser-session-memory.md) | Per-result presentation and ordinary invocation focus/caret/viewport memory, safety and remaining boundaries |
| [`chooser-geometry.md`](chooser-geometry.md) | Anchored rightward expansion, work-area bounds, split overflow and live acceptance limits |
| [`chooser-keyboard-workflow.md`](chooser-keyboard-workflow.md) | **Mandatory interaction contract for every panel:** search/results, editable-only Tab, transactional save/discard, command keys and highlighting |
| [`list-interaction-contract.md`](list-interaction-contract.md) | Mouse-wheel, precision-touchpad, and touch scrolling requirements |
| [`provider-model.md`](provider-model.md) | Shared provider, result, query, and action value contracts |
| [`qml-quality-review.md`](qml-quality-review.md) | QML structure, maintenance decisions, and quality gates |
| [`reviews/lens-session-maintenance-2026-09-27.md`](reviews/lens-session-maintenance-2026-09-27.md) | Latest measured descriptor/routing/host refactor against the saved focus-restoration worktree |
| [`reviews/lens-keyboard-maintenance-2026-09-27.md`](reviews/lens-keyboard-maintenance-2026-09-27.md) | Earlier shared-UI/search refactor, complete clone comparisons and validation limits |
| [`reviews/commonality-2026-09-20.md`](reviews/commonality-2026-09-20.md) | Measured shared frontend refactor, validation, and remaining debt |
| [`reviews/test-pruning-2026-09-27.md`](reviews/test-pruning-2026-09-27.md) | Latest test inventory reduction, retained boundaries and coverage tradeoffs |

## Proposals

- [`proposals/circular-panel-actions.md`](proposals/circular-panel-actions.md): all-panel audit and implementation record for title-aligned primary actions, right-aligned secondary rows and icon-only circular command buttons.
- [`proposals/material-expressive.md`](proposals/material-expressive.md): accepted owner-interview decisions for keyboard-first Material 3 Expressive, remaining design questions, implementation sequence and progress ledger. This defines the target; the ledger distinguishes delivered changes from planned behavior.

## Sources of truth

When documentation and generated evidence differ, use this order:

1. checked daemon protocol fixtures under `contracts/`, including resource wire-shape fixtures exported by their owning daemon;
2. executable tests and strict `qmllint`;
3. QML/JavaScript implementation;
4. these explanatory documents;
5. generated `target/qmlqualitylens/` reports.

Durable state, validation, system policy, timers, persistence, and effects belong to Rust daemons. Shelllist owns presentation, navigation, monitor-local windows, animation, and transient UI state.

## Documentation maintenance

Update the relevant document when changing a user-visible interaction, ownership boundary, daemon stream, shared component contract, or validation command. Use current-state language rather than roadmap language. Keep command examples runnable from the Shelllist repository root.
