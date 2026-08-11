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
    retainOnFocusLoss: controller.navigationBlocked
    onUiActivated: function (workspaceId) { controller.activateUi(workspaceId); }
    onUiDeactivated: controller.deactivateUi()
    onFocusSearchRequested: controller.focusSearchRequested()
    Connections {
        target: host.controller
        function onCloseWindowRequested() { host.closeRequested(); }
        function onScreenshotRequested() {
            const width = Math.round(host.controller.currentWindowWidth);
            const x = Math.round(host.targetWindowX()
                + (host.controller.surfaceWindowWidth - width) / 2);
            host.controller.captureScreenshot(x, host.targetWindowY(), width, host.currentWindowHeight);
        }
    }
}
