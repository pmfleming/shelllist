pragma ComponentBehavior: Bound

import QtQuick
import "."

DetailCard {
    id: card

    required property var controller
    height: 174
    title: "Profile settings"

    Column {
        anchors.fill: parent
        spacing: 8

        Repeater {
            model: card.controller.detailActions.filter(function (action) { return action.setting; })
            delegate: ProfileToggleRow {
                required property var modelData
                title: modelData.label
                hotkey: modelData.hotkey
                subtitle: modelData.subtitle
                checked: modelData.checked
                interactive: modelData.enabled
                onClicked: card.controller.triggerDetailAction(modelData.id)
            }
        }
    }
}
