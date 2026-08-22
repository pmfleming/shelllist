pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property ClipboardController controller
    chooserController: controller
    surfaceName: "Clipboard"
    readonly property var selectedEntry: content.controller.selectedEntry || ({})
    readonly property bool actionsEnabled: content.controller.uiActive
        && content.controller.hasSelection && !content.controller.actionInFlight
        && !content.controller.wipeChallenge && !content.controller.navigationHelpOpen
    navigationEnabled: !content.controller.navigationHelpOpen
    refreshEnabled: !content.controller.actionInFlight && !content.controller.navigationHelpOpen
    helpEnabled: content.controller.uiActive && !content.controller.detailState.editorFocused
        && !content.controller.deleteConfirmationOpen && !content.controller.wipeChallenge
    helpEntries: [
        { keys: "Ctrl+Enter", action: "Copy without pasting" },
        { keys: "Shift+Enter", action: "Paste an image as a file" },
        { keys: "Delete", action: "Delete the selected entry" },
        { keys: "F5", action: "Refresh clipboard history" }
    ]
    onRefreshRequested: content.controller.refresh()

    listComponent: Component {
        ClipboardListPane { controller: content.controller }
    }
    detailsComponent: Component {
        ClipboardDetails { controller: content.controller; uiScale: content.uiScale }
    }

    Shortcut {
        sequence: "Return"
        enabled: content.actionsEnabled && content.selectedEntry.kind !== "binary"
            && !content.controller.detailState.editorFocused
        onActivated: content.controller.pasteSelected()
    }
    Shortcut {
        sequence: "Ctrl+Return"
        enabled: content.actionsEnabled
        onActivated: content.controller.copySelected()
    }
    Shortcut {
        sequence: "Shift+Return"
        enabled: content.actionsEnabled && content.selectedEntry.kind === "image"
        onActivated: content.controller.pasteImageAsFile()
    }
    Shortcut {
        sequence: "Delete"
        enabled: content.actionsEnabled
        onActivated: content.controller.requestDelete()
    }

    Connections {
        target: content.controller
        function onHideRequested() { content.controller.closeWindowRequested(); }
    }

    Ui.ConfirmationDialog {
        visible: content.controller.deleteConfirmationOpen
        z: 120
        title: "Delete clipboard entry?"
        detail: "This entry will be permanently removed from Ringboard history."
        acceptLabel: "Delete"
        onAccepted: content.controller.confirmDelete()
        onCancelled: content.controller.cancelDelete()
    }
    Ui.ConfirmationDialog {
        visible: !!content.controller.wipeChallenge
        z: 120
        title: "Clear clipboard history?"
        detail: "This permanently removes regular and favorite entries plus generated previews."
        acceptLabel: "Clear all"
        onAccepted: content.controller.confirmWipe()
        onCancelled: content.controller.cancelWipe()
    }
}
