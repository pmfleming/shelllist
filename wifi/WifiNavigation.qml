import QtQuick

Item {
    required property var controller

    function accept(event, action) { action(); event.accepted = true; }
    function isEnter(key) { return key === Qt.Key_Return || key === Qt.Key_Enter; }
    function isPlainHotkey(event, hotkey) { return event.key === hotkey.charCodeAt(0) && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier); }
    function move(delta) { controller.selectionModel.move(delta); }

    function openDetails() {
        if (controller.detailsOpen)
            return;
        controller.detailsOpen = true;
        controller.detailsExpansionProgress = 1;
        controller.windowPlacementRequested();
    }

    function closeDetails() {
        if (!controller.detailsOpen)
            return;
        controller.detailsOpen = false;
        controller.detailsExpansionProgress = 0;
        controller.windowPlacementRequested();
    }

    function toggleDetails() { controller.detailsOpen ? closeDetails() : openDetails(); }
    function focusListTop() { controller.selectedIndex = 0; controller.focusListTopRequested(); }
    function focusSearch() { controller.focusSearchRequested(); }

    function handleBinding(event, bindings) {
        for (let index = 0; index < bindings.length; index++)
            if (event.key === bindings[index][0])
                return accept(event, bindings[index][1]);
    }

    function paneBindings(downAction) {
        return [
            [Qt.Key_Escape, controller.closeWindowRequested],
            [Qt.Key_Down, downAction],
            [Qt.Key_Up, function () { move(-1); }],
            [Qt.Key_Right, openDetails]
        ];
    }

    function handleSearchKey(event) {
        if (controller.prompt.open)
            return;
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        return handleBinding(event, paneBindings(focusListTop));
    }

    function handleDetailHotkey(event) {
        if (!controller.detailsOpen)
            return false;
        const action = controller.detailActions.find(function (item) { return isPlainHotkey(event, item.shortcut) && item.visible && item.enabled; });
        if (!action)
            return false;
        accept(event, function () { controller.triggerDetailAction(action.id); });
        return true;
    }

    function handleListKey(event) {
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        if (handleDetailHotkey(event))
            return;
        if (event.key === Qt.Key_Left)
            return accept(event, closeDetails);
        if (event.key === Qt.Key_Up && controller.selectedIndex <= 0)
            return accept(event, focusSearch);
        return handleBinding(event, paneBindings(function () { move(1); }));
    }
}
