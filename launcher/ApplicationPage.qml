import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    objectName: "applicationPage"
    viewMemory: controller.viewMemory
    memoryTab: "application"
    cardSpacing: Ui.Theme.cardGap

    required property ApplicationController controller
    required property var application
    required property real uiScale

    function revealCollection(anchor: Item): void {
        Qt.callLater(function() {
            if (!page || page.tearingDown || !anchor) return;
            page.revealItem(anchor);
            page.contentY = Math.max(0, Math.min(page.contentHeight - page.height, anchor.mapToItem(page.contentItem, 0, 0).y));
        });
    }

    Ui.ThemeText {
        objectName: "applicationDescription"
        visible: !!page.application.comment && page.application.comment !== (page.controller.selectedResult || {}).subtitle
        width: parent.width
        text: page.application.comment || ""
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
    }

    Ui.ContentState {
        objectName: "applicationEmptyState"
        visible: page.application.kind === "desktop-shortcut" || (page.application.instances || []).length === 0
        width: parent.width
        height: Math.max(112 * page.uiScale, implicitHeight + Ui.Theme.spacingXxl)
        compact: true
        uiScale: page.uiScale
        icon: page.application.kind === "desktop-shortcut" ? "open_in_new" : "web_asset_off"
        showLabel: false
        text: page.application.kind === "desktop-shortcut" ? qsTr("This shortcut opens content in another application") : page.application.kind === "desktop-application" ? qsTr("No open windows\nUse Launch beside the application name to get started.") : qsTr("Window is no longer available")
        Rectangle {
            anchors.fill: parent
            z: -1
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surfaceContainer
        }
    }

    ApplicationInstanceList {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
        onPageChanged: function(anchor) { page.revealCollection(anchor); }
    }

    ApplicationDesktopActions {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
        onPageChanged: function(anchor) { page.revealCollection(anchor); }
    }

    Ui.ContentState {
        objectName: "applicationNoActions"
        visible: page.application.kind === "desktop-application" && (page.application.desktop_actions || []).length === 0
        width: parent.width
        // Applications reserves four shared rows for its empty actions section.
        height: 4 * Ui.Theme.listRowHeight * page.uiScale
        compact: true
        uiScale: page.uiScale
        icon: "extension_off"
        showLabel: false
        text: qsTr("No additional actions provided by this application.")
        Rectangle {
            anchors.fill: parent
            z: -1
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surfaceContainer
        }
    }

}
