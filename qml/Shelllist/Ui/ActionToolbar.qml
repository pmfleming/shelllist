pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

RowLayout {
    id: toolbar

    property var actions: []
    property string group: "toolbar"
    property bool includeAllGroups: false
    property bool alignRight: true
    property bool fillActions: false
    property bool tabFocusEnabled: true
    property int shortcutOffset: -1
    property int controlHeight: Theme.controlHeight

    signal triggered(string actionId)

    spacing: Theme.spacingSm

    Item {
        visible: !toolbar.fillActions && toolbar.alignRight
        Layout.fillWidth: true
    }

    Repeater {
        model: (toolbar.actions || []).filter(function (action) {
            return action.visible !== false && (toolbar.includeAllGroups || ((action.presentation || {}).group || "toolbar") === toolbar.group);
        })

        delegate: ActionButton {
            required property var modelData
            required property int index
            Accessible.description: [toolTip, toolbar.shortcutOffset >= 0 ? qsTr("Shortcut Alt+%1").arg(toolbar.shortcutOffset + index + 1) : ""].filter(Boolean).join(". ")
            objectName: "detailAction:" + modelData.id
            activeFocusOnTab: toolbar.tabFocusEnabled && enabled && (interactive || activeFocus)

            Layout.fillWidth: toolbar.fillActions
            Layout.preferredWidth: toolbar.fillActions ? -1 : (iconOnly ? toolbar.controlHeight : (Number((modelData.presentation || {}).width) || 104))
            Layout.preferredHeight: toolbar.controlHeight
            label: modelData.label || ""
            icon: modelData.icon || ""
            hotkey: modelData.shortcut || ""
            toolTip: (modelData.metadata || {}).toolTip || ""
            tone: (modelData.presentation || {}).tone || "normal"
            enabled: modelData.enabled !== false
            onClicked: toolbar.triggered(modelData.id)
        }
    }

    Item {
        visible: !toolbar.fillActions && !toolbar.alignRight
        Layout.fillWidth: true
    }
}
