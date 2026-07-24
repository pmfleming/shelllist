pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailsPane {
    id: pane

    required property ClipboardController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : ({})
    readonly property var files: detailState.value ? detailState.value.files : []
    readonly property var firstFile: files.length > 0 ? files[0] : ({})
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int toolbarHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property bool textEditable: ["text", "link", "html", "json", "color"].indexOf(entry.kind) >= 0

    function triggerAction(actionId) {
        const handlers = ({
            paste: controller.pasteSelected, copy: controller.copySelected,
            edit: detailState.editing ? detailState.commitEdit : detailState.beginEdit,
            "cancel-edit": detailState.cancelEdit, "open-url": controller.openUrl,
            "open-file": function () { controller.openFile(0); },
            "reveal-file": function () { controller.revealFile(0); },
            "image-as-file": controller.imageAsFile, annotate: controller.annotateImage,
            favorite: controller.toggleFavorite, "delete": controller.requestDelete,
            "close-details": controller.closeDetails
        });
        handlers[actionId]();
    }

    chooserController: controller
    densityScale: uiScale
    emptyText: "Select a clipboard entry"

    RowLayout {
            width: parent.width
            height: pane.headerHeight
            spacing: Ui.Theme.spacingMd

            Ui.IconTile {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 54
                icon: pane.selected.icon || "󰅇"
                iconColor: pane.entry.current ? Ui.Theme.active : Ui.Theme.accent
                iconSize: Math.round(Ui.Theme.iconSizeLarge * pane.uiScale)
                backgroundColor: Ui.Theme.selected
                borderColor: Ui.Theme.strongBorder
            }

            Ui.ResultLabel {
                title: pane.selected.title || "Clipboard entry"
                subtitle: pane.selected.subtitle || ""
                subtitleColor: Ui.Theme.mutedText
                titleWeight: Ui.Theme.fontWeightBold
                titlePixelSize: Math.round(Ui.Theme.fontSizeTitle * pane.uiScale)
                subtitlePixelSize: Math.max(Ui.Theme.fontSizeCaption, Math.round(Ui.Theme.fontSizeSmall * pane.uiScale))
            }
        }

        Ui.ActionToolbar {
            width: parent.width
            height: pane.toolbarHeight
            actions: [{
                id: "paste", label: pane.controller.targetAvailable ? "Paste" : "Copy", icon: "󰆒", shortcut: "Enter",
                visible: pane.entry.kind !== "binary", enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "active", width: 104 }
            }, {
                id: "copy", label: "Copy", icon: "󰆏", shortcut: "Ctrl+↵",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 96 }
            }, {
                id: "edit", label: pane.detailState.editing ? "Save" : "Edit", icon: "󰏫", shortcut: "",
                visible: pane.textEditable, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: pane.detailState.editing ? "active" : "normal", width: 88 }
            }, {
                id: "cancel-edit", label: "Cancel", icon: "󰜺", shortcut: "Esc",
                visible: pane.detailState.editing, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }, {
                id: "open-url", label: "Open", icon: "󰌷", shortcut: "",
                visible: pane.entry.kind === "link" && !pane.detailState.editing, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 88 }
            }, {
                id: "open-file", label: "Open", icon: "󰷏", shortcut: "",
                visible: pane.files.length > 0, enabled: !pane.controller.actionInFlight && !!pane.firstFile.exists,
                presentation: { group: "toolbar", tone: "normal", width: 88 }
            }, {
                id: "reveal-file", label: "Reveal", icon: "󰉋", shortcut: "",
                visible: pane.files.length > 0, enabled: !pane.controller.actionInFlight && !!pane.firstFile.exists,
                presentation: { group: "toolbar", tone: "normal", width: 96 }
            }, {
                id: "image-as-file", label: "As file", icon: "󰈔", shortcut: "Shift+↵",
                visible: pane.entry.kind === "image", enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 106 }
            }, {
                id: "annotate", label: "Annotate", icon: "󰏫", shortcut: "",
                visible: pane.entry.kind === "image", enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 112 }
            }, {
                id: "favorite", label: pane.entry.favorite ? "Unpin" : "Pin", icon: "󰓎", shortcut: "",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: pane.entry.favorite ? "active" : "normal", width: 88 }
            }, {
                id: "delete", label: "Delete", icon: "󰆴", shortcut: "Del",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "danger", width: 96 }
            }, {
                id: "close-details", label: "Back", icon: "󰁍", shortcut: "Left",
                visible: true, enabled: true,
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }]
            group: "toolbar"
            alignRight: false
            controlHeight: pane.toolbarHeight
            onTriggered: function (actionId) { pane.triggerAction(actionId); }
        }

        Item {
            width: parent.width
            height: Math.max(0, parent.height - pane.headerHeight - pane.toolbarHeight - 2 * pane.sectionSpacing)

            Ui.CenteredMessage {
                anchors.fill: parent
                visible: pane.detailState.loading
                text: "Loading entry details…"
                font.pixelSize: Ui.Theme.fontSizeTitle
            }
            Ui.CenteredMessage {
                anchors.fill: parent
                visible: !pane.detailState.loading && pane.detailState.error.length > 0
                text: pane.detailState.error
                font.pixelSize: Ui.Theme.fontSizeBody
            }

        ClipboardDetailCards {
            anchors.fill: parent
            visible: !pane.detailState.loading
                && pane.detailState.error.length === 0
                && !!pane.detailState.value
            controller: pane.controller
        }
    }
}
