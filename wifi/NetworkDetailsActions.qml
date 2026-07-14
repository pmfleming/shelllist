pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: row

    required property var controller
    width: parent ? parent.width : 0
    height: 46
    spacing: 8

    Repeater {
        model: row.controller.detailActions.filter(function (action) { return action.toolbar && action.visible; })
        delegate: ActionButton {
            required property var modelData
            Layout.preferredWidth: modelData.width
            label: modelData.label
            hotkey: modelData.hotkey
            backgroundColor: modelData.tone === "danger" ? Theme.danger : (modelData.tone === "active" ? Theme.active : Theme.surfaceRaised)
            borderColor: modelData.tone === "danger" ? Theme.danger : (modelData.tone === "active" ? Theme.active : Theme.mix(Theme.border, Theme.text, 0.16))
            labelColor: modelData.tone === "danger" ? Theme.dangerText : (modelData.tone === "active" ? Theme.activeText : Theme.text)
            enabled: modelData.enabled
            onClicked: row.controller.triggerDetailAction(modelData.id)
        }
    }

    Item { Layout.fillWidth: true }
}
