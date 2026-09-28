import QtQuick
import Quickshell.Services.SystemTray
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import "SystemEntries.js" as Entries

Ui.ProviderChooserController {
    id: chooser
    required property string kind
    property BarController barController: null
    property bool trayMenuActive: false
    navigationBlocked: trayMenuActive
    readonly property string title: kind === "audio" ? qsTr("Audio") : (kind === "media" ? qsTr("Media") : qsTr("Tray"))
    readonly property string detailsTab: "details"
    readonly property var trayItems: kind === "tray" ? SystemTray.items.values : []
    readonly property var sourceEntries: kind === "tray" ? Entries.tray(trayItems)
        : (!barController ? [] : (kind === "audio" ? Entries.audio(barController.audio, actionInFlight) : Entries.media(barController.media.players, actionInFlight)))
    readonly property var selectedPlayer: kind === "media" && barController && selectedResult ? (barController.media.players || []).find(player => player.id === selectedResult.id) || null : null
    readonly property bool mediaPreferencesSupported: !!selectedPlayer && selectedPlayer.control_mode !== undefined && barController.media.pinned_player !== undefined
    readonly property bool playerPinned: !!selectedPlayer && barController.media.pinned_player === selectedPlayer.id
    readonly property string direction: selectedResult ? selectedResult.metadata.direction : ""
    readonly property bool muted: !!barController && (direction === "input" ? barController.audio.input_muted : barController.audio.muted)
    readonly property string statusText: barController && kind !== "tray" ? barController.backend.operationError : ""
    actionInFlight: !!barController && kind !== "tray" && (!barController.backend.ready || barController.backend.requestRunning)
    providerRankedResults: true
    closeDetailsWithoutSelection: true
    viewMemory: Ui.ChooserMemory {
        controller: chooser
        key: chooser.selectedResult ? chooser.selectedResult.key : ""
        tab: "details"
        initialTab: "details"
        tabs: ["details"]
        onRestoreRequested: function (open, tab) { chooser.detailsOpen = open; }
    }
    provider: Core.Provider {
        providerId: chooser.kind
        displayName: chooser.title
        function execute(request: var): bool {
            return chooser.perform(request.actionId, request.result.id);
        }
    }
    signal trayMenuRequested(SystemTrayItem item)

    onSourceEntriesChanged: if (uiActive) refresh()
    onFilterTextChanged: if (uiActive) refresh()
    function activateUi(workspaceId: string): void {
        activateUiState(workspaceId);
        refresh();
    }
    function refresh(): void {
        if (!uiActive)
            return;
        const query = beginProviderQuery({});
        const words = filterText.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
        applyProviderQuery(query.id, sourceEntries.filter(function (entry) {
            return words.every(word => entry.searchText.toLocaleLowerCase().includes(word));
        }).map(entry => provider.makeResult(entry)));
    }
    function primarySelected(): bool {
        if (!hasSelection)
            return false;
        openDetails();
        focusDetailsRequested();
        return true;
    }
    function triggerDetailAction(actionId: string): bool {
        return executeSelected(actionId);
    }
    function uniqueTrayItem(id: string): SystemTrayItem {
        const matches = Array.from(trayItems).filter(item => item.id === id);
        return matches.length === 1 ? matches[0] : null;
    }
    function setMediaSelection(pin: bool): bool {
        return !actionInFlight && uiActive && mediaPreferencesSupported && barController.backend.mediaPreference(pin ? "select" : "automatic", pin ? selectedPlayer.id : "", "");
    }
    function setMediaMode(mode: string): bool {
        return !actionInFlight && uiActive && mediaPreferencesSupported && ["automatic", "tracks", "seek"].includes(mode) && barController.backend.mediaPreference("set-mode", selectedPlayer.id, mode);
    }
    function toggleAudioMuted(): bool {
        if (kind !== "audio" || !uiActive || actionInFlight || !selectedResult || !barController
                || !sourceEntries.some(entry => entry.id === selectedResult.id))
            return false;
        return direction === "input" ? barController.toggleInputMuted() : barController.toggleMuted();
    }
    function perform(actionId: string, id: string): bool {
        if (!uiActive || trayMenuActive)
            return false;
        const entry = sourceEntries.find(value => value.id === id);
        const action = entry && entry.actions.find(value => value.id === actionId && value.enabled !== false);
        if (!action)
            return false;
        if (actionId === "inspect")
            return primarySelected();
        if (kind === "audio") {
            if (actionId === "mixer")
                return barController.triggerModuleAction("audio-mixer");
            return barController.adjustAudio(actionId === "quieter" ? -5 : 5);
        }
        if (kind === "media") {
            const seek = actionId === "rewind" || actionId === "forward";
            return barController.backend.mediaOperationFor(id, seek ? "seek" : actionId, seek ? (actionId === "rewind" ? -30 : 30) : null);
        }
        const item = uniqueTrayItem(id);
        if (!item)
            return false;
        if (actionId === "menu") trayMenuRequested(item);
        else if (actionId === "activate") item.activate();
        else if (actionId === "secondary") item.secondaryActivate();
        else item.scroll(actionId === "scroll-up" ? 15 : -15, false);
        return true;
    }
}
