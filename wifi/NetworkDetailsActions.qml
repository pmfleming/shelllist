import Shelllist.Ui as Ui

Ui.ActionToolbar {
    required property WifiController controller
    property bool primaryOnly: false

    actions: controller.detailActions
    group: primaryOnly ? "primary" : "toolbar"
    onTriggered: function (actionId) { controller.triggerDetailAction(actionId); }
}
