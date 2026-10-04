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
            objectName: toolbar.actionNamePrefix + modelData.id
            activeFocusOnTab: toolbar.tabFocusEnabled && enabled && (interactive || activeFocus)

            Layout.fillWidth: toolbar.fillActions
            Layout.preferredWidth: toolbar.fillActions ? -1 : (iconOnly ? toolbar.controlHeight : (Number((modelData.presentation || {}).width) || 104))
            Layout.preferredHeight: toolbar.controlHeight
            label: modelData.label || ""
            icon: modelData.icon || ""
            iconOnly: !toolbar.showLabels && icon.length > 0
            hotkey: modelData.shortcut || ""
            accessKey: modelData.accessKey || ""
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
