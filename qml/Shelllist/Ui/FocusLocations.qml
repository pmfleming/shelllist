pragma Singleton
import QtQuick

// Resolve ordinary named controls within a scope. Only primitive keys/positions
// leave this helper; visibility, uniqueness and capabilities are checked anew.
QtObject {
    function key(item: Item): string {
        const field = item as TextField;
        return field ? (field.sensitive ? "" : field.focusKey) : item.objectName;
    }
    function targets(root: Item, name: string): var {
        if (!root || !root.visible || (root as TextField)?.sensitive)
            return [];
        let found = [];
        if ((root instanceof ActionControl || root instanceof TextField || root instanceof IconTile) && key(root) === name)
            found.push(root);
        for (const child of root.children)
            found = found.concat(targets(child, name));
        return found;
    }
    function capture(root: Item, focus: Item): var {
        let target = null;
        while (focus && focus !== root) {
            if (!target && (focus instanceof ActionControl || focus instanceof TextField || focus instanceof IconTile))
                target = focus;
            focus = focus.parent;
        }
        if (focus !== root || !target || !key(target) || targets(root, key(target)).length !== 1)
            return null;
        const field = target as TextField;
        return {target: key(target), selection: field ? field.selectionState() : null};
    }
    function restore(root: Item, state: var): bool {
        if (!state || !state.target)
            return false;
        const found = targets(root, state.target);
        if (found.length !== 1 || !found[0].enabled)
            return false;
        const target = found[0];
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
