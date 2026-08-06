pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.DetailsPane {
    id: pane

    required property ClipboardController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : ({})
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int toolbarHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property bool image: entry.kind === "image"
    readonly property bool link: entry.kind === "link"

    function triggerAction(actionId) {
        if (actionId === "paste") {
            controller.pasteSelected();
        } else if (actionId === "paste-as-file" && image) {
            controller.pasteImageAsFile();
        } else if (actionId === "edit" && image) {
            controller.annotateImage();
        } else if (actionId === "edit" && link) {
            controller.openUrl();
        }
    }

    chooserController: controller
    densityScale: uiScale
    leftMargin: 18
    rightMargin: 16
    emptyText: "Select a clipboard entry"

    Ui.DetailsHeader {
        width: parent.width
        height: pane.headerHeight
        uiScale: pane.uiScale
        icon: pane.selected.icon || "󰅇"
        iconColor: pane.entry.current ? Ui.Theme.active : Ui.Theme.accent
        title: pane.selected.title || "Clipboard entry"
        subtitle: pane.selected.subtitle || ""
        titlePixelSize: Math.round(Ui.Theme.fontSizeTitle * pane.uiScale)
    }

        Ui.ActionToolbar {
            width: parent.width
            height: pane.toolbarHeight
            actions: [{
                id: "paste", label: "Paste", icon: "󰆒", shortcut: "Enter",
                enabled: pane.entry.kind !== "binary" && !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "active", width: 92 }
            }, {
                id: "paste-as-file", label: "Paste as file", icon: "󰈔", shortcut: "Shift+↵",
                visible: pane.image,
                enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 120 }
            }, {
                id: "edit", label: pane.link ? "Open" : "Edit", icon: pane.link ? "󰌷" : "󰏫", shortcut: "",
                visible: pane.image || pane.link,
                enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 92 }
            }]
            group: "toolbar"
            alignRight: true
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
