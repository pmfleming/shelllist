pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list

    property var actions: []
    property int rowHeight: 36
    property bool distributeRows: false
    property bool showDisabledReason: true

    signal triggered(string actionId)

    spacing: Theme.spacingSm

    Repeater {
        id: actionRepeater
        model: list.actions

        delegate: ToggleRow {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: list.distributeRows
                ? Math.max(30, (list.height - list.spacing * Math.max(0, actionRepeater.count - 1))
                    / Math.max(1, actionRepeater.count))
                : list.rowHeight
            title: modelData.label || ""
            hotkey: modelData.shortcut || ""
            checked: !!(modelData.state && modelData.state.checked)
            tone: (modelData.presentation || {}).tone || "normal"
            interactive: modelData.enabled !== false
            subtitle: modelData.subtitle || (list.showDisabledReason && modelData.enabled === false
                ? ((modelData.metadata || {}).disabledReason || "Unavailable") : "")
            showSubtitle: subtitle.length > 0
            onClicked: list.triggered(modelData.id)
        }
    }
}
