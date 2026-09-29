import QtQuick

Item {
    id: shortcuts

    required property ChooserController controller
    property bool navigationEnabled: true
    property bool refreshEnabled: false
    property bool detailsTabEnabled: false
    property bool refreshAutoRepeat: true

    signal refreshRequested
    signal detailsTabRequested(bool backwards)
    function dismiss(): void {
        controller.dismissNavigation();
    }

    Shortcut {
        sequence: "Escape"
        enabled: shortcuts.controller.uiActive && shortcuts.navigationEnabled
        autoRepeat: false
        onActivated: shortcuts.dismiss()
    }
    Shortcut {
        sequence: "F5"
        enabled: shortcuts.controller.uiActive && shortcuts.refreshEnabled
        autoRepeat: shortcuts.refreshAutoRepeat
        onActivated: shortcuts.refreshRequested()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: shortcuts.controller.uiActive && shortcuts.detailsTabEnabled
        onActivated: shortcuts.detailsTabRequested(false)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: shortcuts.controller.uiActive && shortcuts.detailsTabEnabled
        onActivated: shortcuts.detailsTabRequested(true)
    }
}
