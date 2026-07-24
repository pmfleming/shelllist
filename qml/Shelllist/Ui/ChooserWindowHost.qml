import QtQuick
PopupWindowHost {
    id: host
    required property ChooserController controller
    required property string applicationId
    required property string displayName
    modeEnvironment: "SHELLLIST_" + applicationId.toUpperCase() + "_MODE"
    ipcTarget: applicationId
    shortcutName: applicationId
    shortcutDescription: "Toggle the Shelllist " + displayName + " chooser"
    windowTitle: "Shelllist " + displayName
    layerNamespace: "shelllist-" + applicationId
    surfaceWindowWidth: controller.surfaceWindowWidth
    currentWindowWidth: controller.currentWindowWidth
    onUiActivated: function (workspaceId) { controller.activateUi(workspaceId); }
    onUiDeactivated: controller.deactivateUi()
    onFocusSearchRequested: controller.focusSearchRequested()
    Connections {
        target: host.controller
        function onCloseWindowRequested() { host.closeRequested(); }
    }
}
