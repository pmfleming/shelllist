import QtQuick

Shortcut {
    required property ChooserController controller

    sequence: "Alt+S"
    enabled: controller !== null && controller.uiActive && !controller.uiSuspending
    autoRepeat: false
    onActivated: controller.screenshotRequested()
}
