pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls

// Header overflow and content commands share modality, traversal and focus
// return. Owners supply actions and presentation adapters, retaining effects.
Controls.Popup {
    id: menu
    required property var actions
    property int controlHeight: Theme.controlHeight
    property int maximumVisibleItems: 6
    property string accessibleName: qsTr("More actions")
    property alias listObjectName: list.objectName
    property Item returnFocus: null
    signal triggered(var action)
    width: Math.min(parent.width, 360)
    height: Math.min(actions.length, maximumVisibleItems) * controlHeight + padding * 2
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
    function available(index: int): bool {
        const action = actions[index];
        return !!action && action.enabled !== false;
    }
    function labelFor(index: int): string {
        return actions[index]?.label || "";
    }
    function activate(index: int): void {
        if (!available(index))
            return;
        // Closing restores focus and can change the model: route the captured
        // action, never look it up again by index after closing.
        const action = actions[index];
        close();
        triggered(action);
    }
    background: Rectangle {
        radius: Theme.controlRadius
        color: Theme.surfaceRaised
        border.color: Theme.border
    }
    contentItem: ListView {
        id: list
        model: menu.visible ? menu.actions : []
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Accessible.role: Accessible.PopupMenu
        Accessible.name: menu.accessibleName
        function moveSelection(delta: int): void {
            for (let n = 1; n <= count; ++n) {
                const index = (currentIndex + delta * n + count) % count;
                if (menu.available(index)) {
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
            required property int index
            width: list.width
            height: menu.controlHeight
            text: menu.labelFor(index)
            enabled: menu.available(index)
            highlighted: list.currentIndex === index
            focusPolicy: Qt.NoFocus
            Accessible.role: Accessible.MenuItem
            Accessible.focused: list.activeFocus && highlighted
            Accessible.onPressAction: menu.activate(index)
            onClicked: menu.activate(index)
        }
    }
}
