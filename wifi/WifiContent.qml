pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

ProviderChooserSurface {
    id: content

    required property WifiController controller
    chooserController: controller
    surfaceName: "Wi-Fi"
    navigationEnabled: !content.controller.promptActive && !content.controller.navigationHelpOpen
    refreshEnabled: content.controller.powered && navigationEnabled && !content.controller.actionInFlight
    refreshAutoRepeat: false
    helpEnabled: content.controller.uiActive && !content.controller.promptActive
    refreshHelp: "Refresh and scan for networks"
    readonly property bool pageShortcutsEnabled: content.controller.uiActive && content.controller.powered && content.navigationEnabled && !content.controller.advanced.open

    function cancelPrompt(): void {
        content.controller.cancelPrompt("user");
    }

    listComponent: Component {
        NetworkListPane {
            controller: content.controller
        }
    }
    detailsComponent: Component {
        NetworkDetailsPane {
            controller: content.controller
        }
    }

    SurfaceShortcut {
        sequence: "F6"
        help: "Connect to a hidden network"
        enabled: content.pageShortcutsEnabled
        autoRepeat: false
        onActivated: content.controller.openHiddenNetworkPrompt()
    }
    SurfaceShortcut {
        sequence: "F7"
        help: "Open Security & Privacy"
        enabled: content.pageShortcutsEnabled
        onActivated: content.controller.advanced.openSettings("security")
    }
    SurfaceShortcut {
        sequence: "F8"
        help: "Open IP & DNS"
        enabled: content.pageShortcutsEnabled
        onActivated: content.controller.advanced.openSettings("hardware")
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
        onInputEdited: function (text) {
            content.controller.prompt.text = text;
        }
        onOptionEdited: function (requested) {
            content.controller.prompt.saveSecret = requested;
        }
        onAccepted: content.controller.prompt.submit(content.controller)
        onCancelled: content.cancelPrompt()
    }

    WifiCredentialDialog {
        visible: content.controller.prompt.credentialOpen
        prompt: content.controller.prompt
        onAccepted: function (values) {
            content.controller.prompt.submitCredentials(content.controller, values);
        }
        onCancelled: content.cancelPrompt()
    }

    WifiQrDialog {
        visible: content.controller.qr.open
        qr: content.controller.qr
        onClosed: content.controller.qr.close()
    }
}
