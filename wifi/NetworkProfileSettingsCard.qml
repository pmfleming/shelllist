pragma ComponentBehavior: Bound

import QtQuick
import "."

DetailCard {
    id: card

    required property var controller
    height: 174
    title: "Profile settings"

    Column {
        id: settings

        anchors.fill: parent
        spacing: card.height < 155 ? 3 : 7

        Repeater {
            id: settingRepeater

            model: card.controller.detailActions.filter(function (action) { return action.setting; })

            delegate: ProfileToggleRow {
                required property var modelData

                height: Math.max(30, (settings.height - settings.spacing * Math.max(0, settingRepeater.count - 1)) / Math.max(1, settingRepeater.count))
                title: modelData.label
                hotkey: modelData.hotkey
                subtitle: modelData.subtitle
                showSubtitle: card.height >= 145
                checked: modelData.checked
                interactive: modelData.enabled
                onClicked: card.controller.triggerDetailAction(modelData.id)
            }
        }
    }
}
