import Quickshell

PanelWindow { // qmllint disable uncreatable-type
    required property var targetScreen
    required property BarController controller
    readonly property string focusedScreenName: controller.workspaces
        ? (controller.workspaces.focused_monitor || "") : ""
    readonly property bool targetIsFocused: focusedScreenName.length > 0
        ? (!!screen && screen.name === focusedScreenName)
        : (Quickshell.screens.length > 0 && screen === Quickshell.screens[0])

    screen: targetScreen
    visible: targetIsFocused
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
}
