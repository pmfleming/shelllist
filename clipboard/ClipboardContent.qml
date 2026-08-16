pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ClipboardController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property var selectedEntry: controller.selectedEntry || ({})

    Shortcut {
        sequence: "Escape"
        enabled: content.controller.uiActive && !content.controller.navigationHelpOpen
        onActivated: content.controller.dismissNavigation()
    }
    Shortcut {
        sequence: "F5"
        enabled: content.controller.uiActive && !content.controller.actionInFlight
            && !content.controller.navigationHelpOpen
        onActivated: content.controller.refresh()
    }
    Shortcut {
        sequence: "Return"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && content.selectedEntry.kind !== "binary"
            && !content.controller.detailState.editorFocused && !content.controller.actionInFlight
            && !content.controller.wipeChallenge && !content.controller.navigationHelpOpen
        onActivated: content.controller.pasteSelected()
    }
    Shortcut {
        sequence: "Ctrl+Return"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && !content.controller.actionInFlight && !content.controller.wipeChallenge
            && !content.controller.navigationHelpOpen
        onActivated: content.controller.copySelected()
    }
    Shortcut {
        sequence: "Shift+Return"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && content.selectedEntry.kind === "image"
            && !content.controller.actionInFlight && !content.controller.wipeChallenge
            && !content.controller.navigationHelpOpen
        onActivated: content.controller.pasteImageAsFile()
    }
    Shortcut {
        sequence: "Delete"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && !content.controller.actionInFlight && !content.controller.wipeChallenge
            && !content.controller.navigationHelpOpen
        onActivated: content.controller.requestDelete()
    }

    Ui.SplitChooserLayout {
        controller: content.controller
        listComponent: Component {
            ClipboardListPane { controller: content.controller; uiScale: content.uiScale }
        }
        detailsComponent: Component {
            ClipboardDetails { controller: content.controller; uiScale: content.uiScale }
        }
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

    Ui.NavigationHelpDialog {
        controller: content.controller
        surfaceName: "Clipboard"
        helpEnabled: content.controller.uiActive
            && !content.controller.detailState.editorFocused
            && !content.controller.deleteConfirmationOpen && !content.controller.wipeChallenge
        entries: [
            { keys: "Ctrl+Enter", action: "Copy without pasting" },
            { keys: "Shift+Enter", action: "Paste an image as a file" },
            { keys: "Delete", action: "Delete the selected entry" },
            { keys: "F5", action: "Refresh clipboard history" }
        ]
    }
}
