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

    Ui.DetailRows {
        objectName: "applicationVersions"
        width: parent.width
        visible: !!page.application.software
        title: qsTr("Versions")
        rows: page.application.software ? [
            {label: qsTr("Local"), value: Ui.SoftwarePresentation.local(page.application.software)},
            {label: qsTr("Latest"), value: Ui.SoftwarePresentation.latest(page.application.software)},
            {label: qsTr("Source"), value: Ui.SoftwarePresentation.details(page.application.software) || qsTr("No package version reported")}
        ] : []
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

    ApplicationDataDetails {
        width: parent.width
        controller: page.controller
        application: page.application
    }

    ApplicationDesktopActions {
        width: parent.width
        controller: page.controller
        application: page.application
        uiScale: page.uiScale
        onPageChanged: function(anchor) { page.revealCollection(anchor); }
    }

    Ui.ContentState {
        id: noActions
        objectName: "applicationNoActions"
        visible: page.application.kind === "desktop-application" && (page.application.desktop_actions || []).length === 0
        width: parent.width
        // Center the passive mark in the space below app data; short pages scroll.
        height: Math.max(implicitHeight + Ui.Theme.spacingXxl, page.height - noActions.y)
        compact: true
        uiScale: page.uiScale
        icon: "extension_off"
        showLabel: false
        text: qsTr("No additional actions provided by this application.")
    }

}
