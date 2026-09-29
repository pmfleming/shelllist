pragma Singleton
import QtQuick

// Resolve ordinary named controls within a scope. Only primitive keys/positions
// leave this helper; visibility, uniqueness and capabilities are checked anew.
QtObject {
    function key(item: Item): string {
        const field = item as TextField;
        return field ? (field.sensitive ? "" : field.focusKey) : (item ? item.objectName : "");
    }
    function registered(item: Item): bool {
        return item instanceof ActionControl || item instanceof TextField || item instanceof IconTile;
    }
    function uniqueTarget(items: var, name: string): Item {
        if (!name)
            return null;
        const matches = items.filter(item => key(item) === name);
        return matches.length === 1 ? matches[0] : null;
    }
    function targets(root: Item): var {
        if (!root || !root.visible || (root as TextField)?.sensitive)
            return [];
        let found = registered(root) ? [root] : [];
        for (const child of root.children)
            found = found.concat(targets(child));
        return found;
    }
    function capture(root: Item, focus: Item): var {
        let target = null;
        while (focus && focus !== root) {
            if (!target && registered(focus))
                target = focus;
            focus = focus.parent;
        }
        if (focus !== root || !target || uniqueTarget(targets(root), key(target)) !== target)
            return null;
        const field = target as TextField;
        return {target: key(target), selection: field ? field.selectionState() : null};
    }
    function restore(root: Item, state: var): bool {
        if (!state || !state.target)
            return false;
        const target = uniqueTarget(targets(root), state.target);
        if (!target || !target.enabled)
            return false;
        const action = target as ActionControl;
        const field = target as TextField;
        const tile = target as IconTile;
        if ((action && !action.interactive) || (tile && !tile.clickable) || (field && (field.sensitive || field.readOnly)))
            return false;
        if (field) {
            field.focusInput(false);
            field.restoreSelection(state.selection);
        } else {
            target.forceActiveFocus(Qt.OtherFocusReason);
        }
        return true;
    }
}
