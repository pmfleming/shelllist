pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane

    required property ClipboardController controller
    readonly property var selected: controller.selectedResult || ({})
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : ({})
    readonly property int toolbarHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property bool image: entry.kind === "image"
    readonly property bool link: entry.kind === "link"
    readonly property bool binary: entry.kind === "binary"
    readonly property var primaryActions: [{
        id: binary ? "copy" : "paste",
        label: binary ? "Copy" : "Paste",
        icon: binary ? "󰆏" : "󰆒",
        shortcut: "Enter",
        enabled: !!entry.id && !controller.actionInFlight,
        presentation: { group: "primary", tone: "active", width: 112 }
    }]
    readonly property var secondaryActions: [{
        id: "copy", label: "Copy", icon: "󰆏", shortcut: "Ctrl+↵",
        visible: !binary,
        enabled: !!entry.id && !controller.actionInFlight,
        presentation: { group: "toolbar", tone: "normal", width: 92 }
    }, {
        id: "paste-as-file", label: "Paste as file", icon: "󰈔", shortcut: "Shift+↵",
        visible: image,
        enabled: !controller.actionInFlight,
        presentation: { group: "toolbar", tone: "normal", width: 120 }
    }, {
        id: "edit", label: link ? "Open" : "Edit", icon: link ? "󰌷" : "󰏫", shortcut: "",
        visible: image || link,
        enabled: !controller.actionInFlight,
        presentation: { group: "toolbar", tone: "normal", width: 92 }
    }]

    function triggerAction(actionId) {
        if (actionId === "paste") {
            controller.pasteSelected();
        } else if (actionId === "copy") {
            controller.copySelected();
        } else if (actionId === "paste-as-file" && image) {
            controller.pasteImageAsFile();
        } else if (actionId === "edit" && image) {
            controller.annotateImage();
        } else if (actionId === "edit" && link) {
            controller.openUrl();
        }
    }

    chooserController: controller
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select a clipboard entry"
    headerHeight: Math.max(58, Math.round(66 * uiScale))
    controlHeight: toolbarHeight
    icon: selected.icon || "󰅇"
    iconColor: entry.current ? Ui.Theme.active : Ui.Theme.accent
    title: selected.title || "Clipboard entry"
    subtitle: selected.subtitle || ""
    actions: primaryActions.concat(secondaryActions)
    actionWidth: 112
    onActionTriggered: function (actionId) { triggerAction(actionId); }

    Item {
        anchors.fill: parent

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
