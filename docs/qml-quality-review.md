# QML quality review

This review used the local `qmlqualitylens` 0.3 checkout against `qmlqualitylens.config.json`. The before and after runs used `measure all`; QML lint, unit tests, the Nix flake, and a live Quickshell/bar-daemon session provide separate authoritative validation.

## Static results

| Metric | Before | After |
| --- | ---: | ---: |
| Maintainability score | 89 | 90 |
| Source lines | 13,165 | 13,104 |
| Functions/handlers | 1,354 | 1,352 |
| Bindings | 3,968 | 3,909 |
| Findings | 592 | 556 |
| High-risk hotspots | 13 | 11 |
| Highest hotspot score | 147 | 131 |
| Normalized clone groups | 27 | 26 |
| Low-locality components | 15 | 13 |
| Active cleanup findings | 7 | 3 |
| Unresolved types | 3 | 0 |
| Semantic high-severity findings | 1 | 0 |

The aggregate leverage-class counts remain unchanged, but leverage improved at the changed boundaries: `ChooserShortcuts` is a 100-score, four-use shared component; `BarContent` leverage rose while its effort fell from 261 to 141; and `NavigationHelpDialog` leverage rose while effort fell from 200 to 175.

## Refactoring decisions

- Replaced repeated chooser Escape/F5/Ctrl+Tab handlers with `ChooserShortcuts`.
- Replaced ten static bar status blocks with normalized presentation descriptors and one delegate.
- Isolated workspace rendering in `WorkspaceButton` and moved visual policy into presentation helpers.
- Split terminal-operation handling into small transition functions for application, clipboard, and Bluetooth flows.
- Replaced the nested shortcut Flickable/Column/Repeater tree with one ListView.
- Removed unused frontend protocol methods, aliases, policy fields, Bluetooth mutation helpers, and test-only production helpers.
- Removed unused configurable surface load policies; the registry now expresses the one load strategy it actually uses.
- Added explicit QML type evidence for Quickshell/Qt plugin types instead of leaving unresolved symbols.

The remaining cleanup findings are parser limitations around alias targets and a same-directory component. Existing suppressions document Qt Quick Test discovery and dynamically supplied delegates; this review added no new suppressions.
