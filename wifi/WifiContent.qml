pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

Rectangle {
    id: content

    required property WifiController controller
    readonly property real uiScale: Theme.densityScale(height, controller.contentVerticalMargin)

    anchors.fill: parent
    radius: Theme.windowRadius
    color: Theme.window
    border.color: Theme.strongBorder
    border.width: 1

    function cancelPrompt() {
        controller.cancelPrompt("user");
    }

    Shortcut {
        sequence: "F5"
        enabled: content.controller.powered && !content.controller.prompt.open && !content.controller.actionInFlight
        autoRepeat: false
        onActivated: content.controller.refresh()
    }

    Shortcut {
        sequence: "F6"
        enabled: content.controller.powered && !content.controller.prompt.open && !content.controller.advanced.open
        autoRepeat: false
        onActivated: content.controller.openHiddenNetworkPrompt()
    }

    Shortcut {
        sequence: "F7"
        enabled: content.controller.powered && !content.controller.prompt.open && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("security")
    }

    Shortcut {
        sequence: "F8"
        enabled: content.controller.powered && !content.controller.prompt.open && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("hardware")
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection && !content.controller.prompt.open
        onActivated: content.controller.cycleDetailsTab()
    }

    Shortcut {
        sequence: "Escape"
        enabled: content.controller.advanced.open && !content.controller.prompt.open
        autoRepeat: false
        onActivated: content.controller.advanced.closeSettings()
    }

    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.prompt.open && !content.controller.advanced.open
        autoRepeat: false
        onActivated: content.controller.closeWindowRequested()
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(chooser.listItem.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(chooser.listItem.focusTop); }
    }

    SplitChooserLayout {
        id: chooser
        controller: content.controller
        listComponent: Component {
            ColumnLayout {
                spacing: Math.round(10 * content.uiScale)

                function focusSearch() { header.focusSearch(); }
                function focusTop() { listPane.focusTop(); }

                ChooserHeader {
                    id: header
                    uiScale: content.uiScale
                    placeholder: "Search networks…"
                    signalIcon: true
                    focusOnCompleted: true
                    filterText: content.controller.filterText
                    powered: content.controller.powered
                    refreshing: content.controller.scanInFlight
                    powerEnabled: !content.controller.actionInFlight && !content.controller.prompt.open
                    refreshEnabled: content.controller.powered && !content.controller.actionInFlight
                    onFilterEdited: function (text) {
                        content.controller.filterText = text;
                        content.controller.selectedIndex = 0;
                    }
                    onKeyPressed: function (event) { content.controller.navigation.handleSearchKey(event); }
                    onPowerRequested: content.controller.setPower()
                    onRefreshRequested: content.controller.refresh()
                }

                NetworkListPane {
                    id: listPane
                    controller: content.controller
                    uiScale: content.uiScale
                }
            }
        }
        detailsComponent: Component {
            NetworkDetailsPane {
                controller: content.controller
            }
        }
    }

    PromptDialog {
        visible: content.controller.prompt.open
        title: content.controller.prompt.title
        detail: content.controller.prompt.detail
        inputText: content.controller.prompt.text
        password: content.controller.prompt.password
        optionVisible: content.controller.prompt.mode === "daemon-secret" && content.controller.prompt.saveSecretSupported
        optionChecked: content.controller.prompt.saveSecret
        optionLabel: "Save in the desktop keyring"
        actionsVisible: true
        rejectLabel: "Cancel"
        acceptLabel: content.controller.prompt.mode === "confirm-forget" ? "Confirm" : "Continue"
        onInputEdited: function (text) { content.controller.prompt.text = text; }
        onOptionEdited: function (requested) { content.controller.prompt.saveSecret = requested; }
        onAccepted: content.controller.prompt.submit(content.controller)
        onCancelled: content.cancelPrompt()
    }
}
