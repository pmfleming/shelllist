pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list

    property var actions: []
    property int rowHeight: 56
    property bool showDisabledReason: true

    signal triggered(string actionId)

    spacing: Theme.spacingSm

    Repeater {
        model: list.actions

        delegate: ToggleRow {
            required property var modelData
            objectName: "detailSetting:" + modelData.id

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(implicitHeight, list.rowHeight)
            title: modelData.label || ""
            hotkey: modelData.shortcut || ""
            checked: !!(modelData.state && modelData.state.checked)
            tone: (modelData.presentation || {}).tone || "normal"
            interactive: modelData.enabled !== false
            subtitle: modelData.subtitle || (list.showDisabledReason && modelData.enabled === false ? ((modelData.metadata || {}).disabledReason || "Unavailable") : "")
            showSubtitle: subtitle.length > 0
            onClicked: list.triggered(modelData.id)
        }
    }
}
