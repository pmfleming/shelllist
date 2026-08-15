pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

ChooserSurface {
    id: content

    required property WifiController controller
    readonly property real uiScale: Theme.densityScale(height, controller.contentVerticalMargin)

    function cancelPrompt() {
        controller.cancelPrompt("user");
    }

    Shortcut {
        sequence: "F5"
        enabled: content.controller.powered && !content.controller.promptActive
            && !content.controller.navigationHelpOpen && !content.controller.actionInFlight
        autoRepeat: false
        onActivated: content.controller.refresh()
    }

    Shortcut {
        sequence: "F6"
        enabled: content.controller.powered && !content.controller.promptActive
            && !content.controller.navigationHelpOpen && !content.controller.advanced.open
        autoRepeat: false
        onActivated: content.controller.openHiddenNetworkPrompt()
    }

    Shortcut {
        sequence: "F7"
        enabled: content.controller.powered && !content.controller.promptActive
            && !content.controller.navigationHelpOpen && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("security")
    }

    Shortcut {
        sequence: "F8"
        enabled: content.controller.powered && !content.controller.promptActive
            && !content.controller.navigationHelpOpen && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("hardware")
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection
            && !content.controller.promptActive && !content.controller.navigationHelpOpen
        onActivated: content.controller.cycleDetailsTab()
    }

    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.promptActive && !content.controller.navigationHelpOpen
        autoRepeat: false
        onActivated: content.controller.dismissNavigation()
    }

    SplitChooserLayout {
        controller: content.controller
        listComponent: Component {
            NetworkListPane {
                controller: content.controller
                uiScale: content.uiScale
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

    WifiCredentialDialog {
        visible: content.controller.prompt.credentialOpen
        prompt: content.controller.prompt
        onAccepted: function (values) { content.controller.prompt.submitCredentials(content.controller, values); }
        onCancelled: content.cancelPrompt()
    }

    WifiQrDialog {
        visible: content.controller.qr.open
        qr: content.controller.qr
        onClosed: content.controller.qr.close()
    }

    NavigationHelpDialog {
        controller: content.controller
        surfaceName: "Wi-Fi"
        helpEnabled: !content.controller.promptActive
        entries: [
            { keys: "F5", action: "Refresh and scan for networks" },
            { keys: "F6", action: "Connect to a hidden network" },
            { keys: "F7", action: "Open Security & Privacy" },
            { keys: "F8", action: "Open IP & DNS" },
            { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
        ]
    }
}
