pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui
import Shelllist.Core as Core

DetailCard {
    id: card

    required property WifiController controller
    height: 174
    title: qsTr("Profile settings")

    ActionToggleList {
        anchors.fill: parent
        spacing: card.height < 155 ? 3 : 7
        distributeRows: true
        showDisabledReason: false
        actions: Core.Model.visibleActions(card.controller.detailActions, "settings")
        onTriggered: function (actionId) {
            card.controller.triggerDetailAction(actionId);
        }
    }
}
