import QtQuick

// Application-defined action names are opaque, not an invitation to guess an
// icon. A single circular launcher opens their fully named menu entries.
Item {
    id: list
    required property var actions
    property int controlHeight: Theme.secondaryActionHeight
    signal triggered(string actionKey)
    visible: actions.length > 0
    implicitHeight: visible ? controlHeight : 0
    onActionsChanged: menu.close()
    onVisibleChanged: if (!visible) menu.close()
    onEnabledChanged: if (!enabled) menu.close()

    ActionButton {
        id: more
        objectName: "notificationAppActions"
        anchors.right: parent.right
        width: list.controlHeight
        height: width
        icon: "more_horiz"
        label: qsTr("Application actions")
        onClicked: menu.open()
        ActionMenu {
            id: menu
            actions: list.actions
            y: more.height
            x: more.width - width
            width: Math.min(list.width, 320)
            controlHeight: Theme.secondaryActionHeight
            listObjectName: "notificationAppActionMenu"
            onTriggered: function(action) { list.triggered(action.key); }
        }
    }
}
