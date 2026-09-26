pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property ClipboardController controller
    chooserController: controller
    surfaceName: "Clipboard"
    readonly property var selectedEntry: content.controller.selectedEntry || ({})
    readonly property bool actionsEnabled: content.controller.uiActive && content.controller.hasSelection && !content.controller.multiSelectMode && !content.controller.deleteMenuOpen && !content.controller.actionInFlight && !content.controller.wipeChallenge && !content.controller.navigationHelpOpen
    detailsTabEnabled: content.actionsEnabled && content.controller.detailsOpen
    helpEnabled: content.controller.uiActive && !content.controller.multiSelectMode && !content.controller.deleteMenuOpen && !content.controller.detailState.editorFocused && !content.controller.deleteConfirmationOpen && !content.controller.bulkDeleteConfirmationOpen && !content.controller.wipeChallenge
    refreshHelp: "Refresh clipboard history"
    helpShortcuts: [pasteShortcut, copyShortcut, imageShortcut, deleteShortcut, selectAllShortcut]

    listComponent: Component {
        ClipboardListPane {
            controller: content.controller
        }
    }
    detailsComponent: Component {
        ClipboardDetails {
            controller: content.controller
            uiScale: content.uiScale
        }
    }

    Ui.SurfaceShortcut {
        id: pasteShortcut
        sequence: "Return"
        enabled: content.actionsEnabled && content.selectedEntry.kind !== "binary" && !content.controller.detailState.editorFocused
        onActivated: content.controller.pasteSelected()
    }
    Ui.SurfaceShortcut {
        id: copyShortcut
        sequence: "Ctrl+Return"
        help: "Copy without pasting"
        enabled: content.actionsEnabled
        onActivated: content.controller.copySelected()
    }
    Ui.SurfaceShortcut {
        id: imageShortcut
        sequence: "Shift+Return"
        help: "Paste an image as a file"
        enabled: content.actionsEnabled && content.selectedEntry.kind === "image"
        onActivated: content.controller.pasteImageAsFile()
    }
    Ui.SurfaceShortcut {
        id: deleteShortcut
        sequence: "Delete"
        help: "Delete the selected entry"
        enabled: content.controller.uiActive && !content.controller.actionInFlight && !content.controller.deleteMenuOpen && (content.controller.multiSelectMode ? content.controller.multiSelectedCount > 0 : content.controller.hasSelection)
        onActivated: {
            if (content.controller.multiSelectMode)
                content.controller.requestBulkDelete();
            else
                content.controller.requestDelete();
        }
    }
    Ui.SurfaceShortcut {
        id: selectAllShortcut
        sequence: "Ctrl+A"
        help: "Select all in multi-select mode"
        enabled: content.controller.uiActive && content.controller.multiSelectMode && !content.controller.actionInFlight
        onActivated: content.controller.selectAllVisible()
    }

    Connections {
        target: content.controller
        function onHideRequested() {
            content.controller.closeWindowRequested();
        }
    }

    Ui.PromptDialog {
        visible: content.controller.deleteMenuOpen
        z: 120
        title: qsTr("Delete clipboard entries")
        detail: "Delete the current item, choose several items, or clear the complete history."
        inputVisible: false
        actionsVisible: false
        instruction: "Esc close"
        onCancelled: content.controller.closeDeleteMenu()

        Ui.ActionToggleList {
            width: parent.width
            actions: [
                {
                    id: "current",
                    label: "Delete current item",
                    subtitle: content.controller.selectedEntry ? content.controller.selectedEntry.preview : "No item selected",
                    enabled: content.controller.hasSelection,
                    presentation: {
                        tone: "danger"
                    }
                },
                {
                    id: "multiple",
                    label: "Select multiple…",
                    subtitle: "Choose individual entries, then delete them together",
                    enabled: content.controller.filteredResults.length > 0
                },
                {
                    id: "all",
                    label: "Delete all history…",
                    subtitle: "Remove regular entries, favorites, and generated previews",
                    enabled: true,
                    presentation: {
                        tone: "danger"
                    }
                }
            ]
            onTriggered: function (actionId) {
                if (actionId === "current")
                    content.controller.requestDeleteCurrent();
                else if (actionId === "multiple")
                    content.controller.enterMultiSelect();
                else if (actionId === "all")
                    content.controller.requestDeleteAll();
            }
        }
    }
    Ui.ConfirmationDialog {
        visible: content.controller.deleteConfirmationOpen
        z: 120
        title: qsTr("Delete clipboard entry?")
        detail: "This entry will be permanently removed from Ringboard history."
        acceptLabel: "Delete"
        onAccepted: content.controller.confirmDelete()
        onCancelled: content.controller.cancelDelete()
    }
    Ui.ConfirmationDialog {
        visible: content.controller.bulkDeleteConfirmationOpen
        z: 120
        title: "Delete " + content.controller.multiSelectedCount + " clipboard entries?"
        detail: "Only the selected entries will be permanently removed."
        acceptLabel: "Delete selected"
        onAccepted: content.controller.confirmBulkDelete()
        onCancelled: content.controller.cancelBulkDelete()
    }
    Ui.ConfirmationDialog {
        visible: !!content.controller.wipeChallenge
        z: 120
        title: qsTr("Clear clipboard history?")
        detail: "This permanently removes regular and favorite entries plus generated previews."
        acceptLabel: "Clear all"
        onAccepted: content.controller.confirmWipe()
        onCancelled: content.controller.cancelWipe()
    }
}
