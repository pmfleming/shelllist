pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property SystemChooserController controller
    chooserController: controller
    keyboardWorkflow: true
    navigationEnabled: !controller.trayMenuActive
    property Item menuReturnFocus: null
    property int menuGeneration: -1
    function finishMenu(): void {
        menuDeadline.stop();
        const target = menuReturnFocus;
        const pending = controller && controller.trayMenuActive;
        menuReturnFocus = null;
        if (!controller)
            return;
        controller.trayMenuActive = false;
        if (!pending || !controller.uiActive || controller.uiSuspending || controller.uiGeneration !== menuGeneration)
            return;
        if (target && target.visible && target.enabled)
            target.forceActiveFocus();
        else if (listItem)
            listItem.focusSearch();
    }
    function cancelMenu(): void {
        trayMenu.close();
        trayMenu.menu = null;
        finishMenu();
    }
    QsMenuAnchor {
        id: trayMenu
        objectName: "systemTrayMenu"
        anchor.item: content.menuReturnFocus || content
        onOpened: {
            menuDeadline.stop();
            if (!content.controller.uiActive || !content.controller.trayMenuActive || content.controller.uiGeneration !== content.menuGeneration)
                content.cancelMenu();
        }
        onClosed: content.finishMenu()
    }
    Timer {
        id: menuDeadline
        interval: 1500
        onTriggered: if (!trayMenu.visible) content.cancelMenu()
    }
    Component.onDestruction: {
        menuGeneration = -1;
        cancelMenu();
    }
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
                Column {
                    width: parent.width
                    visible: content.controller.kind === "media"
                    spacing: Ui.Theme.spacingMd
                    Ui.ToggleRow {
                        objectName: "mediaPlayerPin"
                        title: qsTr("Pin this player")
                        subtitle: qsTr("Automatic selection resumes when the pinned player exits")
                        checked: content.controller.playerPinned
                        enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                        onClicked: content.controller.setMediaSelection(!checked)
                    }
                    Ui.ActionButton {
                        objectName: "mediaAutomatic"
                        width: Ui.Theme.controlHeight
                        height: width
                        icon: "󰑓"
                        label: qsTr("Resume automatic player selection")
                        enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                        onClicked: content.controller.setMediaSelection(false)
                    }
                    Ui.ThemeText { text: qsTr("Bar controls for this player") }
                    Ui.DropDownList {
                        objectName: "mediaControlMode"
                        width: parent.width
                        value: content.controller.selectedPlayer ? content.controller.selectedPlayer.control_mode || "automatic" : "automatic"
                        options: [
                            {value: "automatic", label: qsTr("Automatic (unknown content seeks ±30 seconds)")},
                            {value: "tracks", label: qsTr("Previous/next track")},
                            {value: "seek", label: qsTr("Seek ±30 seconds")}
                        ]
                        enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                        onSelected: function (value) { content.controller.setMediaMode(value); }
                    }
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
            // Retain the layer surface before native menu focus can clear its grab.
            content.controller.navigationInteracted();
            content.menuReturnFocus = content.Window.window ? content.Window.window.activeFocusItem : null;
            content.menuGeneration = content.controller.uiGeneration;
            content.controller.trayMenuActive = true;
            trayMenu.menu = item.menu;
            menuDeadline.restart();
            trayMenu.open();
        }
        function onUiActiveChanged(): void {
            if (!content.controller.uiActive)
                content.cancelMenu();
        }
    }
}
