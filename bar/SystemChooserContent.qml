pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Shelllist.Ui as Ui

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
        if (["spotify", "pocketcasts", "audible"].includes(metadata.serviceIcon))
            return Qt.resolvedUrl("assets/media/" + metadata.serviceIcon + ".png").toString();
        // A recognized web service need not have an installed icon. Keep the
        // player identity as fallback; never substitute a logo for cover art.
        return name && Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
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
        placeholder: tray ? qsTr("Search tray applications…") : audio ? qsTr("Search audio devices…") : qsTr("Search media players…")
        readonly property bool tray: content.controller.kind === "tray"
        readonly property bool audio: content.controller.kind === "audio"
        readonly property bool media: content.controller.kind === "media"
        readonly property string readError: !tray && content.controller.barController ? content.controller.barController.backend.snapshotError : ""
        readonly property bool reading: !tray && !!content.controller.barController && content.controller.barController.backend.snapshotLoading
        emptyIcon: tray ? "apps" : audio ? "speaker" : "music_note"
        emptyState: readError ? "unavailable" : reading ? "loading" : !tray && (!content.controller.barController || !content.controller.barController.backend.ready) ? "unavailable" : filterText.trim() && content.controller.sourceEntries.length > 0 ? "filtered" : "empty"
        emptyText: readError || (emptyState === "loading" ? (audio ? qsTr("Reading audio devices…") : qsTr("Looking for media players…"))
            : emptyState === "unavailable" ? (audio ? qsTr("Audio service unavailable") : qsTr("Media service unavailable"))
            : emptyState === "filtered" ? (tray ? qsTr("No matching tray applications") : audio ? qsTr("No matching audio devices") : qsTr("No matching players"))
            : tray ? qsTr("No tray applications") : audio ? qsTr("No audio devices") : qsTr("No media players"))
        refreshing: reading
        powerVisible: false
        icon: media ? "󰝚" : ""
        powered: media && !!content.controller.barController && content.controller.barController.backend.ready
        status: content.controller.statusText || (media ? readError || (emptyState === "unavailable" ? emptyText
            : reading ? qsTr("Looking for media players…")
            : content.controller.actionInFlight ? qsTr("Updating media…")
            : resultCount === 0 ? emptyText
            : filterText.trim() ? (content.controller.sourceEntries.length === 1 ? qsTr("%1 of %n player", "", 1) : qsTr("%1 of %n players", "", content.controller.sourceEntries.length)).arg(resultCount)
            : resultCount === 1 ? qsTr("%n player", "", resultCount) : qsTr("%n players", "", resultCount)) : "")
        statusTone: content.controller.statusText || (media && (readError || emptyState === "unavailable")) ? "error" : "info"
        statusSummary: statusTone !== "error" ? status : audio ? qsTr("Audio change unconfirmed") : tray ? qsTr("Tray status") : content.controller.statusText ? qsTr("Media change unconfirmed") : qsTr("Media service unavailable")
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            objectName: "systemResult:" + resultData.id
            listPane: pane
            rowHeight: pane.delegateHeight
            readonly property bool inViewport: !!ListView.view
                && y + height > ListView.view.contentY
                && y < ListView.view.contentY + ListView.view.height
            readonly property SystemTrayItem trayItem: content.controller.kind === "tray" ? content.controller.uniqueTrayItem(resultData.id) : null
            leadingIcon: resultData.icon || "󰀻"
            leadingIconSource: trayItem ? trayItem.icon : content.applicationIconSource(resultData)
            accessibleName: resultData.title + ". " + (resultData.subtitle || "") + ". " + (resultData.metadata.playbackStatus || "")
            Ui.ResultLabel {
                title: row.resultData.title
                subtitle: row.resultData.subtitle
            }
            Ui.PlaybackIndicator {
                objectName: "mediaSessionState"
                visible: content.controller.kind === "media"
                glyph: row.resultData.metadata.stateIcon || ""
                active: content.controller.uiActive && !content.controller.uiSuspending
                    && !!content.controller.barController?.backend.ready && row.inViewport
            }
        }
    }
    detailsComponent: SystemChooserDetails {
        controller: content.controller
        iconSource: content.controller.selectedTrayItem ? content.controller.selectedTrayItem.icon : content.applicationIconSource(content.controller.selectedResult)
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
