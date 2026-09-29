pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Core as Core

RowLayout {
    id: toolbar

    property var actions: []
    property string group: "toolbar"
    property bool includeAllGroups: false
    property bool alignRight: true
    property bool fillActions: false
    property bool showLabels: false
    property string actionNamePrefix: "detailAction:"
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
        model: Core.Model.visibleActions(toolbar.actions, toolbar.includeAllGroups ? undefined : toolbar.group, "toolbar")

        delegate: ActionButton {
            required property var modelData
            required property int index
            Accessible.description: [toolTip, toolbar.shortcutOffset >= 0 ? qsTr("Shortcut Alt+%1").arg(toolbar.shortcutOffset + index + 1) : ""].filter(Boolean).join(". ")
            objectName: toolbar.actionNamePrefix + modelData.id
            activeFocusOnTab: toolbar.tabFocusEnabled && enabled && (interactive || activeFocus)

            Layout.fillWidth: toolbar.fillActions
            Layout.preferredWidth: toolbar.fillActions ? -1 : (iconOnly ? toolbar.controlHeight : (Number((modelData.presentation || {}).width) || 104))
            Layout.preferredHeight: toolbar.controlHeight
            label: modelData.label || ""
            icon: modelData.icon || ""
            iconOnly: !toolbar.showLabels && icon.length > 0
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
