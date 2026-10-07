pragma ComponentBehavior: Bound

import QtQuick
import "."
import Shelllist.Ui

ProviderChooserSurface {
    id: content

    required property WifiController controller
    chooserController: controller
    sessionReady: !controller.advanced.loading
    navigationEnabled: !content.controller.promptActive
    refreshEnabled: content.controller.powered && navigationEnabled
    refreshAutoRepeat: false
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

    Shortcut {
        sequence: "F6"
        enabled: content.pageShortcutsEnabled
        autoRepeat: false
        onActivated: content.controller.openHiddenNetworkPrompt()
    }
    Shortcut {
        sequence: "F7"
        enabled: content.pageShortcutsEnabled
        onActivated: content.controller.advanced.openSettings("security")
    }
    Shortcut {
        sequence: "F8"
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
