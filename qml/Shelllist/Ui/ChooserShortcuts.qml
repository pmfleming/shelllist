import QtQuick

Item {
    id: shortcuts

    required property ChooserController controller
    property bool navigationEnabled: true
    property bool refreshEnabled: false
    property bool detailsTabEnabled: false
    property bool refreshAutoRepeat: true

    signal refreshRequested
    signal detailsTabRequested

    Shortcut {
        sequence: "Escape"
        enabled: shortcuts.controller.uiActive && shortcuts.navigationEnabled
        autoRepeat: false
        onActivated: shortcuts.controller.dismissNavigation()
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
        onActivated: shortcuts.detailsTabRequested()
    }
}
