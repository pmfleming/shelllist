pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui
import Shelllist.Core as Core

DetailColumnCard {
    id: card

    required property WifiController controller
    title: qsTr("Profile settings")

    ActionToggleList {
        Layout.fillWidth: true
        showDisabledReason: false
        actions: Core.Model.visibleActions(card.controller.detailActions, "settings")
        onTriggered: function (actionId) {
            card.controller.triggerDetailAction(actionId);
        }
    }
}
