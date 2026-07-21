import QtQuick

Item {
    id: navigation

    required property var controller
    property bool blocked: false

    function accept(event, action) { action(); event.accepted = true; }
    function isEnter(key) { return key === Qt.Key_Return || key === Qt.Key_Enter; }
    function isPlainHotkey(event, hotkey) {
        return hotkey && event.key === String(hotkey).charCodeAt(0)
            && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier);
    }
    function move(delta) { controller.selectionModel.move(delta); }

    function openDetails() {
        if (!controller.detailsOpen && controller.hasSelection)
            controller.detailsOpen = true;
    }
    function closeDetails() {
        if (controller.detailsOpen)
            controller.detailsOpen = false;
    }
    function toggleDetails() { controller.detailsOpen ? closeDetails() : openDetails(); }
    function focusListTop() {
        controller.selectedIndex = 0;
        controller.focusListTopRequested();
    }
    function focusSearch() { controller.focusSearchRequested(); }

    function handleDetailHotkey(event) {
        if (!controller.detailsOpen)
            return false;
        const action = (controller.detailActions || []).find(function (item) {
            return navigation.isPlainHotkey(event, item.shortcut) && item.visible !== false && item.enabled !== false;
        });
        if (!action)
            return false;
        accept(event, function () { controller.triggerDetailAction(action.id); });
        return true;
    }

    function handleSearchKey(event) {
        if (blocked)
            return;
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        if (event.key === Qt.Key_Escape)
            return accept(event, controller.closeWindowRequested);
        if (event.key === Qt.Key_Down)
            return accept(event, focusListTop);
        if (event.key === Qt.Key_Up)
            return accept(event, function () { move(-1); });
        if (event.key === Qt.Key_Right)
            return accept(event, openDetails);
    }

    function handleListKey(event) {
        if (blocked)
            return;
        if (isEnter(event.key))
            return accept(event, controller.primarySelected);
        if (handleDetailHotkey(event))
            return;
        if (event.key === Qt.Key_Escape)
            return accept(event, controller.closeWindowRequested);
        if (event.key === Qt.Key_Left)
            return accept(event, closeDetails);
        if (event.key === Qt.Key_Right)
            return accept(event, openDetails);
        if (event.key === Qt.Key_Up && controller.selectedIndex <= 0)
            return accept(event, focusSearch);
        if (event.key === Qt.Key_Up)
            return accept(event, function () { move(-1); });
        if (event.key === Qt.Key_Down)
            return accept(event, function () { move(1); });
    }
}
