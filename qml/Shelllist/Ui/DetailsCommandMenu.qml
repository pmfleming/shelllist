pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

// Unbounded/repeated content actions cannot all have unique one-letter chords.
// Alt+J opens their menu; they never become field Tab stops.
Controls.Popup {
    id: menu
    required property var commands
    property Item returnFocus: null
    width: Math.min(parent.width, 360)
    height: Math.min(commands.length, 7) * Theme.controlHeight + padding * 2
    padding: Theme.spacingSm
    modal: true
    focus: true
    enter: null
    exit: null
    onAboutToShow: returnFocus = parent && parent.Window.window ? parent.Window.window.activeFocusItem : null
    onOpened: {
        list.currentIndex = -1;
        list.moveSelection(1);
        list.forceActiveFocus();
    }
    onClosed: if (returnFocus && returnFocus.visible && returnFocus.enabled)
        returnFocus.forceActiveFocus(Qt.OtherFocusReason)
    function activate(index: int): void {
        const action = commands[index] as ActionControl;
        if (!action || !action.visible || !action.enabled || !action.interactive)
            return;
        close();
        action.activate();
    }
    background: Rectangle {
        radius: Theme.controlRadius
        color: Theme.surfaceRaised
        border.color: Theme.border
    }
    contentItem: ListView {
        id: list
        objectName: "detailsCommandMenu"
        model: menu.visible ? menu.commands : []
        clip: true
        Accessible.role: Accessible.PopupMenu
        Accessible.name: qsTr("Content actions")
        function moveSelection(delta: int): void {
            for (let n = 1; n <= count; ++n) {
                const index = (currentIndex + delta * n + count) % count;
                const action = menu.commands[index];
                if (action && action.enabled && action.interactive) {
                    currentIndex = index;
                    positionViewAtIndex(index, ListView.Contain);
                    return;
                }
            }
        }
        Keys.onPressed: function (event) {
            if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier)) {
                event.accepted = true;
            } else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab, Qt.Key_Backtab].includes(event.key)) {
                moveSelection(event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
                event.accepted = true;
            } else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
                if (!event.isAutoRepeat) menu.activate(currentIndex);
                event.accepted = true;
            }
        }
        delegate: Controls.ItemDelegate {
            required property ActionControl modelData
            required property int index
            width: list.width
            height: Theme.controlHeight
            text: modelData ? modelData.accessibleName || modelData.objectName : ""
            enabled: modelData !== null && modelData.enabled && modelData.interactive
            highlighted: list.currentIndex === index
            focusPolicy: Qt.NoFocus
            Accessible.role: Accessible.MenuItem
            onClicked: menu.activate(index)
        }
    }
}
