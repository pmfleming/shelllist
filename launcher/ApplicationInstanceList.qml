pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: list
    objectName: "applicationInstanceList"

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var instances: application.kind === "desktop-shortcut" ? [] : application.instances || []

    // Reserve the current-window marker even on non-current rows so titles align.
    readonly property real locationWidth: Math.min(Math.max(56 * uiScale,
        ...instances.map(window => workspaceMetrics.advanceWidth(workspaceLabel(window)) + 40 * uiScale)),
        Math.max(56 * uiScale, Math.min(120 * uiScale, width * 0.25)))

    function workspaceLabel(window: var): string {
        return String(window.workspace_name || window.workspace_id || "?");
    }

    FontMetrics {
        id: workspaceMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.round(Ui.Theme.fontSizeLabel * list.uiScale)
    }

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)
    visible: instances.length > 0

    Ui.SectionLabel {
        objectName: "applicationWindowsHeading"
        text: qsTr("Open windows · %1").arg(list.instances.length)
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        contentPadding: 0
        verticalContentPadding: 0
        contentSpacing: 0
        color: Ui.Theme.surfaceContainer
        clip: true

        Repeater {
            model: list.instances
            delegate: ApplicationWindowRow {
                id: windowRow
                controller: list.controller
                applicationId: list.application.id
                applicationName: list.application.name || ""
                uiScale: list.uiScale
                locationWidth: list.locationWidth
                workspaceLabel: list.workspaceLabel(windowRow.modelData)
                workspaceFont: workspaceMetrics.font
            }
        }
    }
}
