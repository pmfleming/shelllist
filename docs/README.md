# Shelllist documentation

The repository README is the user-facing overview and installation guide. These documents define current frontend behavior and architecture; daemon implementation details remain authoritative in each sibling daemon repository.

| Document | Scope |
| --- | --- |
| [`activity.md`](activity.md) | Activity surface, notification grouping, monitor routing, and ownership |
| [`application-launcher.md`](application-launcher.md) | Launcher behavior, lifecycle, resources, and `app-daemon` boundary |
| [`bar-osd.md`](bar-osd.md) | Shared OSD descriptor, event sources, timeout policy, and extension rules |
| [`daemon-frontend-commonality.md`](daemon-frontend-commonality.md) | Common daemon endpoint, recovery, sequencing, and chooser integration contracts |
| [`list-interaction-contract.md`](list-interaction-contract.md) | Mouse-wheel, precision-touchpad, and touch scrolling requirements |
| [`provider-model.md`](provider-model.md) | Shared provider, result, query, and action value contracts |
| [`qml-quality-review.md`](qml-quality-review.md) | QML structure, maintenance decisions, and quality gates |

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
