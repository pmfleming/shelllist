pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

RowLayout {
    id: row

    required property var controller
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
            return action.toolbar && action.visible && (!!action.primary === row.primaryOnly);
        })

        delegate: ActionButton {
            required property var modelData

            Layout.preferredWidth: modelData.width
            Layout.preferredHeight: row.controlHeight
            icon: modelData.icon || ""
            label: modelData.label
            hotkey: modelData.hotkey
            backgroundColor: modelData.tone === "danger" ? Theme.danger : (modelData.tone === "active" ? Theme.active : Theme.surfaceRaised)
            borderColor: modelData.tone === "danger" ? Theme.danger : (modelData.tone === "active" ? Theme.active : Theme.mix(Theme.border, Theme.text, 0.16))
            labelColor: modelData.tone === "danger" ? Theme.dangerText : (modelData.tone === "active" ? Theme.activeText : Theme.text)
            enabled: modelData.enabled
            onClicked: row.controller.triggerDetailAction(modelData.id)
        }
    }

    Item {
        visible: !row.alignRight
        Layout.fillWidth: true
    }
}
