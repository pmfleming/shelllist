import QtQuick

Item {
    required property ChooserController controller
    property bool blocked: false
    property bool primaryEnabled: true
    property bool closeEnabled: true

    function accept(event, action) {
        action();
        event.accepted = true;
    }
    function isEnter(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter;
    }
    function focusListTop() {
        controller.selectFirst();
        controller.focusListTopRequested();
    }
    function focusSearch() {
        controller.focusSearchRequested();
    }
    function moveUp() {
        controller.moveSelection(-1);
    }
    function moveDown() {
        controller.moveSelection(1);
    }

    function handlePrimary(event) {
        if (!primaryEnabled || !isEnter(event.key))
            return false;
        accept(event, controller.primarySelected);
        return true;
    }
    function handleClose(event) {
        if (!closeEnabled || event.key !== Qt.Key_Escape)
            return false;
        accept(event, controller.dismissNavigation);
        return true;
    }
    function enterDetails() {
        controller.openDetails();
        if (controller.detailsOpen)
            controller.focusDetailsRequested();
    }
    function handleSearchText(event) {
        // Printable keys belong to the query, never to result/action hotkeys.
        // GroupSwitch (AltGr) text is supplied by Qt; command chords stay free.
        if (!event.text || event.text.charCodeAt(0) < 32 || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return false;
        controller.searchTextRequested(event.text);
        event.accepted = true;
        return true;
    }
    function handleSearchDirection(event) {
        const actions = ({});
        actions[Qt.Key_Down] = focusListTop;
        actions[Qt.Key_Up] = moveUp;
        if (actions[event.key])
            accept(event, actions[event.key]);
    }
    function handleListDirection(event) {
        const actions = ({});
        actions[Qt.Key_Left] = controller.closeDetails;
        actions[Qt.Key_Right] = enterDetails;
        actions[Qt.Key_Up] = controller.selectionAtStart() ? focusSearch : moveUp;
        actions[Qt.Key_Down] = moveDown;
        if (actions[event.key]) {
            accept(event, actions[event.key]);
            return;
        }
    }

    function handleSearchKey(event) {
        if (blocked)
            return;
        if (handlePrimary(event) || handleClose(event))
            return;
        handleSearchDirection(event);
    }
    function handleListKey(event) {
        if (blocked)
            return;
        if (handlePrimary(event) || handleClose(event) || handleSearchText(event))
            return;
        handleListDirection(event);
    }
}
