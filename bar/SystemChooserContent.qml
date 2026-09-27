pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property SystemChooserController controller
    chooserController: controller
    keyboardWorkflow: true
    sessionContext: controller.selectedResult ? controller.selectedResult.key : ""
    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.filteredResultsModel
        filterText: content.controller.filterText
        placeholder: qsTr("Search %1").arg(content.controller.title)
        emptyText: qsTr("No available %1 items").arg(content.controller.title.toLowerCase())
        powerVisible: false
        status: content.controller.statusText
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            listPane: pane
            rowHeight: pane.delegateHeight
            Ui.ResultLabel {
                title: row.resultData.title
                subtitle: row.resultData.subtitle
            }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedResult ? content.controller.selectedResult.title : ""
        subtitle: content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""
        icon: content.controller.selectedResult ? content.controller.selectedResult.icon : ""
        actions: content.controller.detailActions.filter(action => action.id !== "inspect")
        actionWidth: 0
        Ui.DetailFlickable {
            anchors.fill: parent
            viewMemory: content.controller.viewMemory
            memoryTab: "details"
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.ToggleRow {
                    objectName: "audioMute"
                    visible: content.controller.kind === "audio"
                    title: content.controller.direction === "input" ? qsTr("Mute microphone") : qsTr("Mute output")
                    checked: content.controller.muted
                    enabled: content.controller.hasSelection && !content.controller.actionInFlight
                    onClicked: content.controller.toggleAudioMuted()
                }
                Ui.ThemeText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: content.controller.statusText
                    color: Ui.Theme.danger
                    visible: text.length > 0
                }
            }
        }
    }
    Connections {
        target: content.controller
        function onTrayMenuRequested(item): void {
            // Native menus are opened only by an explicit action, never memory.
            content.controller.navigationInteracted();
            item.display(content.QsWindow.window, Math.round(content.width / 2), 0);
        }
    }
}
