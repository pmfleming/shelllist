pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

RowLayout {
    id: row

    required property WifiController controller
    property bool primaryOnly: false
    property bool alignRight: false
    property int controlHeight: 42

    width: parent ? parent.width : 0
    height: controlHeight
    spacing: 8

    Item {
        visible: row.alignRight
        Layout.fillWidth: true
    }

    Repeater {
        model: row.controller.detailActions.filter(function (action) {
            const group = action.presentation.group;
            return action.visible && (row.primaryOnly ? group === "primary" : group === "toolbar");
        })

        delegate: ActionButton {
            required property var modelData

            Layout.preferredWidth: modelData.presentation.width
            Layout.preferredHeight: row.controlHeight
            icon: modelData.icon || ""
            label: modelData.label
            hotkey: modelData.shortcut
            backgroundColor: modelData.presentation.tone === "danger" ? Theme.danger : (modelData.presentation.tone === "active" ? Theme.active : Theme.surfaceRaised)
            borderColor: modelData.presentation.tone === "danger" ? Theme.danger : (modelData.presentation.tone === "active" ? Theme.active : Theme.mix(Theme.border, Theme.text, 0.16))
            labelColor: modelData.presentation.tone === "danger" ? Theme.dangerText : (modelData.presentation.tone === "active" ? Theme.activeText : Theme.text)
            enabled: modelData.enabled
            onClicked: row.controller.triggerDetailAction(modelData.id)
        }
    }

    Item {
        visible: !row.alignRight
        Layout.fillWidth: true
    }
}
