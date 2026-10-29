pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

ColumnLayout {
    id: list
    objectName: "applicationInstanceList"

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var instances: application.kind === "desktop-shortcut" ? [] : application.instances || []
    signal pageChanged(Item anchor)

    // Reserve the current-window marker even on non-current rows so titles align.
    readonly property real locationWidth: Math.min(Math.max(56 * uiScale,
        ...pager.visibleItems.map(window => workspaceMetrics.advanceWidth(workspaceLabel(window)) + 40 * uiScale)),
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

    Ui.DetailColumnCard {
        objectName: "applicationWindowsCard"
        title: list.instances.length > pager.pageSize ? "" : qsTr("Open windows · %1").arg(list.instances.length)
        Layout.fillWidth: true
        contentSpacing: 0
        color: Ui.Theme.surfaceContainer
        clip: true

        Ui.CollectionPager {
            id: pager
            objectName: "applicationWindowPages"
            title: qsTr("Open windows")
            visible: list.instances.length > pageSize
            items: list.instances
            contextKey: list.application.id || ""
            viewMemory: list.controller.viewMemory
            memoryTab: "application"
            memoryKey: "windows"
            blocked: list.controller.operationBlocked || list.controller.operations.busy(list.application.id)
            onPageRequested: function(offset) {
                if (blocked) return;
                list.controller.detailsClosing();
                pager.showPage(offset);
                list.pageChanged(pager);
            }
        }
        Core.KeyedListModel {
            id: windowRows
            values: pager.visibleItems.map(window => ({key: list.application.id + ":" + window.id,
                applicationId: list.application.id, applicationName: list.application.name || "", payload: window}))
        }
        Repeater {
            model: windowRows
            delegate: ApplicationWindowRow {
                id: windowRow
                required property var resultData
                modelData: resultData.payload
                controller: list.controller
                applicationId: resultData.applicationId
                applicationName: resultData.applicationName
                uiScale: list.uiScale
                locationWidth: list.locationWidth
                workspaceLabel: list.workspaceLabel(windowRow.modelData)
                workspaceFont: workspaceMetrics.font
            }
        }
    }
}
