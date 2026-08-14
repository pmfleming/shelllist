pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

DetailCard {
    id: card

    required property WifiController controller
    height: 174
    title: "Profile settings"

    ActionToggleList {
        anchors.fill: parent
        spacing: card.height < 155 ? 3 : 7
        distributeRows: true
        showDisabledReason: false
        actions: card.controller.detailActions.filter(function (action) {
            return action.presentation.group === "settings" && action.visible;
        })
        onTriggered: function (actionId) { card.controller.triggerDetailAction(actionId); }
    }
}
