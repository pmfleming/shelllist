pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

DetailCard {
    id: card

    required property WifiController controller
    height: 174
    title: "Profile settings"

    Column {
        id: settings

        anchors.fill: parent
        spacing: card.height < 155 ? 3 : 7

        Repeater {
            id: settingRepeater

            model: card.controller.detailActions.filter(function (action) { return action.presentation.group === "settings" && action.visible; })

            delegate: ToggleRow {
                required property var modelData

                height: Math.max(30, (settings.height - settings.spacing * Math.max(0, settingRepeater.count - 1)) / Math.max(1, settingRepeater.count))
                title: modelData.label
                hotkey: modelData.shortcut
                showSubtitle: false
                checked: modelData.state.checked
                interactive: modelData.enabled
                onClicked: card.controller.triggerDetailAction(modelData.id)
            }
        }
    }
}
