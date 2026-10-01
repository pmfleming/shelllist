pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Shelllist.Ui as Ui
import "BarMediaPresentation.js" as Media

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
        onTriggered: if (!trayMenu.visible)
            content.cancelMenu()
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
            readonly property SystemTrayItem trayItem: content.controller.kind === "tray" ? content.controller.uniqueTrayItem(resultData.id) : null
            leadingIcon: resultData.icon || "󰀻"
            leadingIconSource: trayItem ? trayItem.icon : ""
            primaryActionId: resultData.primaryActionId || ""
            accessibleName: resultData.title + ". " + (resultData.subtitle || "")
            Ui.ResultLabel {
                title: row.resultData.title
                subtitle: row.resultData.subtitle
            }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedPlayer ? content.controller.selectedPlayer.identity : content.controller.selectedResult ? content.controller.selectedResult.title : ""
        subtitle: content.controller.selectedPlayer ? content.controller.selectedPlayer.playback_status : content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""
        icon: content.controller.selectedResult ? content.controller.selectedResult.icon : ""
        iconSource: content.controller.selectedTrayItem ? content.controller.selectedTrayItem.icon : ""
        actions: content.controller.kind === "audio" ? content.controller.detailActions.filter(action => !["inspect", "quieter", "louder"].includes(action.id)) : []
        actionWidth: 0
        Ui.DetailFlickable {
            anchors.fill: parent
            viewMemory: content.controller.viewMemory
            memoryTab: "details"
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.DetailColumnCard {
                    visible: content.controller.kind === "audio" && content.controller.direction === "output"
                    height: implicitHeight
                    title: qsTr("Output volume")
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.ThemeText {
                            objectName: "audioVolumeValue"
                            Layout.fillWidth: true
                            text: content.controller.barController && Number.isFinite(content.controller.barController.audio.volume_percent) ? content.controller.barController.audio.volume_percent + "%" : qsTr("Not reported")
                            font.pixelSize: Ui.Theme.fontSizeHeading
                            Accessible.name: qsTr("Volume: %1").arg(text)
                        }
                        Ui.ActionToolbar {
                            actionNamePrefix: "audioVolume-"
                            spacing: 5
                            actions: content.controller.kind === "audio" ? content.controller.detailActions.filter(action => ["quieter", "louder"].includes(action.id)) : []
                            onTriggered: function (actionId) { content.controller.triggerDetailAction(actionId); }
                        }
                    }
                }
                Ui.ToggleRow {
                    objectName: "audioMute"
                    visible: content.controller.kind === "audio"
                    title: content.controller.direction === "input" ? qsTr("Mute microphone") : qsTr("Mute output")
                    checked: content.controller.muted
                    enabled: content.controller.hasSelection && !content.controller.actionInFlight
                    onClicked: content.controller.toggleAudioMuted()
                }
                Ui.DetailColumnCard {
                    objectName: "trayApplication"
                    visible: content.controller.kind === "tray"
                    height: implicitHeight
                    title: qsTr("Application")
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""
                        wrapMode: Text.Wrap
                    }
                    Ui.ActionToolbar {
                        Layout.fillWidth: true
                        actionNamePrefix: "trayPrimary-"
                        fillActions: true
                        showLabels: true
                        spacing: 5
                        actions: content.controller.kind === "tray" ? content.controller.detailActions.filter(action => ["activate", "menu"].includes(action.id)) : []
                        onTriggered: function (actionId) { content.controller.triggerDetailAction(actionId); }
                    }
                }
                Ui.DisclosureSection {
                    objectName: "trayOtherActions"
                    title: qsTr("Other application actions")
                    visible: content.controller.kind === "tray"
                    Ui.ActionToolbar {
                        Layout.fillWidth: true
                        alignRight: false
                        actions: content.controller.kind === "tray" ? content.controller.detailActions.filter(action => !["activate", "menu"].includes(action.id)) : []
                        onTriggered: function (actionId) { content.controller.triggerDetailAction(actionId); }
                    }
                }
                Ui.DetailColumnCard {
                    objectName: "mediaPlayback"
                    height: implicitHeight
                    visible: content.controller.kind === "media"
                    title: qsTr("Now playing")
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: content.controller.selectedPlayer ? content.controller.selectedPlayer.title || qsTr("No track title") : ""
                        wrapMode: Text.WordWrap
                        font.pixelSize: Ui.Theme.fontSizeHeading
                    }
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: content.controller.selectedPlayer ? [content.controller.selectedPlayer.artist, content.controller.selectedPlayer.album].filter(Boolean).join(" · ") : ""
                        visible: text.length > 0
                        wrapMode: Text.WordWrap
                        color: Ui.Theme.mutedText
                    }
                    Ui.ActionToolbar {
                        objectName: "mediaPlaybackActions"
                        Layout.fillWidth: true
                        alignRight: false
                        actions: content.controller.kind === "media" ? content.controller.detailActions : []
                        onTriggered: function (actionId) {
                            content.controller.triggerDetailAction(actionId);
                        }
                    }
                }
                Ui.DisclosureSection {
                    objectName: "mediaPreferences"
                    visible: content.controller.kind === "media"
                    title: qsTr("Player preferences")
                    Column {
                        Layout.fillWidth: true
                        spacing: Ui.Theme.spacingMd
                        Ui.ToggleRow {
                            objectName: "mediaPlayerPin"
                            title: qsTr("Pin this player")
                            subtitle: checked ? qsTr("Automatic selection resumes when this player exits") : ""
                            checked: content.controller.playerPinned
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onClicked: content.controller.setMediaSelection(!checked)
                        }
                        Ui.ActionButton {
                            objectName: "mediaAutomatic"
                            width: parent.width
                            visible: content.controller.mediaPreferencesSupported && !!content.controller.barController.media.pinned_player
                            label: qsTr("Resume automatic player selection")
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onClicked: content.controller.setMediaSelection(false)
                        }
                        Ui.ThemeText {
                            text: qsTr("Bar controls for this player")
                        }
                        Ui.DropDownList {
                            objectName: "mediaControlMode"
                            width: parent.width
                            value: content.controller.selectedPlayer ? content.controller.selectedPlayer.control_mode || "automatic" : "automatic"
                            options: [
                                {
                                    value: "automatic",
                                    label: qsTr("Automatic")
                                },
                                {
                                    value: "tracks",
                                    label: qsTr("Previous/next track")
                                },
                                {
                                    value: "seek",
                                    label: qsTr("Seek ±30 seconds")
                                }
                            ]
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onSelected: function (value) {
                                content.controller.setMediaMode(value);
                            }
                        }
                        Ui.ThemeText {
                            width: parent.width
                            visible: !!content.controller.selectedPlayer && content.controller.selectedPlayer.control_mode === "automatic"
                            text: Media.trackControls(content.controller.selectedPlayer) ? qsTr("Music: previous/next track") : qsTr("Other or unknown content: seek ±30 seconds")
                            wrapMode: Text.Wrap
                            color: Ui.Theme.mutedText
                        }
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
