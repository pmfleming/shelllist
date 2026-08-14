import QtQuick

Item {
    id: navigation

    required property ChooserController controller
    property bool blocked: false
    property bool primaryEnabled: true
    property bool closeEnabled: true

    function accept(event, action) { action(); event.accepted = true; }
    function isEnter(key) { return key === Qt.Key_Return || key === Qt.Key_Enter; }
    function isPlainHotkey(event, hotkey) {
        return hotkey && event.key === String(hotkey).charCodeAt(0)
            && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier);
    }
    function focusListTop() {
        controller.selectFirst();
        controller.focusListTopRequested();
    }
    function focusSearch() { controller.focusSearchRequested(); }
    function moveUp() { controller.moveSelection(-1); }
    function moveDown() { controller.moveSelection(1); }

    function handlePrimary(event) {
        if (!primaryEnabled || !isEnter(event.key)) return false;
        accept(event, controller.primarySelected);
        return true;
    }
    function handleClose(event) {
        if (!closeEnabled || event.key !== Qt.Key_Escape) return false;
        accept(event, controller.closeWindowRequested);
        return true;
    }
    function handleDetailHotkey(event) {
        if (!controller.detailsOpen)
            return false;
        const action = controller.detailActions.find(function (item) {
            return navigation.isPlainHotkey(event, item.shortcut)
                && item.visible !== false && item.enabled !== false;
        });
        if (!action)
            return false;
        accept(event, function () { controller.triggerDetailAction(action.id); });
        return true;
    }
    function handleSearchDirection(event) {
        const actions = ({});
        actions[Qt.Key_Down] = focusListTop;
        actions[Qt.Key_Up] = moveUp;
        if (actions[event.key]) accept(event, actions[event.key]);
    }
    function handleListDirection(event) {
        const actions = ({});
        actions[Qt.Key_Left] = controller.closeDetails;
        actions[Qt.Key_Right] = controller.openDetails;
        actions[Qt.Key_Up] = controller.selectionAtStart() ? focusSearch : moveUp;
        actions[Qt.Key_Down] = moveDown;
        if (actions[event.key]) accept(event, actions[event.key]);
    }

    function handleSearchKey(event) {
        if (blocked) return;
        if (handlePrimary(event) || handleClose(event)) return;
        handleSearchDirection(event);
    }
    function handleListKey(event) {
        if (blocked) return;
        if (handlePrimary(event) || handleDetailHotkey(event) || handleClose(event)) return;
        handleListDirection(event);
    }
}
