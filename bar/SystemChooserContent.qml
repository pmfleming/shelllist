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
    navigationEnabled: !controller.trayMenuActive
    property Item menuReturnFocus: null
    property int menuGeneration: -1
    function applicationIconSource(result): string {
        const metadata = result && result.metadata ? result.metadata : {};
        const name = String(metadata.desktopEntry || "");
        const names = metadata.serviceIcon ? metadata.iconNames || [] : [name];
        const installed = names.find(candidate => candidate && Quickshell.hasThemeIcon(candidate));
        if (installed) return Quickshell.iconPath(installed);
        return ["spotify", "pocketcasts", "audible"].includes(metadata.serviceIcon)
            ? Qt.resolvedUrl("assets/media/" + metadata.serviceIcon + ".png").toString() : "";
    }
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
            objectName: "systemResult:" + resultData.id
            listPane: pane
            rowHeight: pane.delegateHeight
            readonly property SystemTrayItem trayItem: content.controller.kind === "tray" ? content.controller.uniqueTrayItem(resultData.id) : null
            leadingIcon: resultData.icon || "󰀻"
            leadingIconSource: trayItem ? trayItem.icon : content.applicationIconSource(resultData)
            accessibleName: resultData.title + ". " + (resultData.subtitle || "") + ". " + (resultData.metadata.playbackStatus || "")
            Ui.ResultLabel {
                title: row.resultData.title
                subtitle: row.resultData.subtitle
            }
            Ui.GlyphLabel {
                objectName: "mediaSessionState"
                visible: content.controller.kind === "media"
                glyph: row.resultData.metadata.stateIcon || ""
                color: row.resultData.metadata.stateIcon === "equalizer" ? Ui.Theme.active : Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.iconSize
                Accessible.ignored: true
            }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedPlayer ? Media.heading(content.controller.selectedPlayer) : content.controller.selectedResult ? content.controller.selectedResult.title : ""
        subtitle: content.controller.selectedPlayer ? Media.identityLabel(content.controller.selectedPlayer) : content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""
        icon: content.controller.selectedResult ? content.controller.selectedResult.icon : ""
        iconSource: content.controller.selectedTrayItem ? content.controller.selectedTrayItem.icon : content.applicationIconSource(content.controller.selectedResult)
        actions: content.controller.detailActions.filter(action => !["inspect", "quieter", "louder"].includes(action.id)).map(action => Object.assign({}, action, {
                presentation: Object.assign({}, action.presentation, {
                    group: content.controller.kind === "media" ? Media.actionGroup(content.controller.selectedPlayer, action.id) : action.id === "activate" ? "primary" : "toolbar"
                })
            }))
        Ui.DetailFlickable {
            anchors.fill: parent
            viewMemory: content.controller.viewMemory
            memoryTab: "details"
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.DetailColumnCard {
                    visible: content.controller.kind === "audio" && content.controller.direction === "output"
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
                            onTriggered: function (actionId) {
                                content.controller.triggerDetailAction(actionId);
                            }
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
                    title: qsTr("Application")
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: content.controller.selectedResult ? content.controller.selectedResult.subtitle : ""
                        wrapMode: Text.Wrap
                    }
                }
                MediaPlaybackCard {
                    objectName: "mediaPlayback"
                    visible: content.controller.kind === "media"
                    player: content.controller.selectedPlayer
                    active: content.controller.uiActive && !!content.controller.barController && content.controller.barController.backend.ready
                }
                Ui.DetailColumnCard {
                    objectName: "mediaPreferences"
                    visible: content.controller.kind === "media"
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.ToggleRow {
                            objectName: "mediaPlayerPin"
                            Layout.fillWidth: true
                            title: qsTr("Pin to bar")
                            accessibleName: qsTr("Pin this session to the bar until it exits")
                            checked: content.controller.playerPinned
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onClicked: content.controller.setMediaSelection(!checked)
                        }
                        Ui.ActionButton {
                            icon: "autorenew"
                            objectName: "mediaAutomatic"
                            accessKey: "A"
                            sizeRole: "secondary"
                            uiScale: Ui.Theme.expandedSecondaryActionScale
                            visible: content.controller.mediaPreferencesSupported && !!content.controller.barController.media.pinned_player && !content.controller.playerPinned
                            label: qsTr("Resume automatic player selection")
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onClicked: content.controller.setMediaSelection(false)
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Ui.Theme.border
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Ui.ThemeText {
                            Layout.fillWidth: true
                            text: qsTr("Bar controls")
                            font.pixelSize: Ui.Theme.fontSizeHeading
                            wrapMode: Text.Wrap
                        }
                        Ui.DropDownList {
                            objectName: "mediaControlMode"
                            Layout.preferredWidth: 220
                            Layout.minimumWidth: 0
                            compact: true
                            Accessible.name: qsTr("Bar controls")
                            value: content.controller.selectedPlayer ? content.controller.selectedPlayer.control_mode || "automatic" : "automatic"
                            options: [
                                {value: "automatic", label: qsTr("Automatic"), icon: "autorenew"},
                                {value: "tracks", label: qsTr("Previous/next track"), icon: "skip_next"},
                                {value: "seek", label: qsTr("Seek ±30 seconds"), icon: "replay_30"}
                            ]
                            enabled: content.controller.mediaPreferencesSupported && !content.controller.actionInFlight
                            onSelected: function (value) {
                                content.controller.setMediaMode(value);
                            }
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
