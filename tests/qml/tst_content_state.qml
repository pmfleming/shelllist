pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Core as Core
import Shelllist.Io as Io
import Shelllist.Bar as Bar
import "../../qml/Shelllist/Activity" as Activity
import "../../wifi" as Wifi
import "../../bluetooth" as Bluetooth
import "../../clipboard" as Clipboard
import "../../launcher" as Apps
import "../../qml/Shelllist/Displays" as Displays
import "../../qml/Shelllist/Battery" as Battery

DaemonTestCase {
    id: testCase
    name: "ContentState"
    when: windowShown
    visible: true
    width: 1050
    height: 720

    Component {
        id: messageFactory
        Ui.ContentState { width: 300; height: 240; icon: "content_paste"; text: "Clipboard history is empty" }
    }
    Component {
        id: surfaceFactory
        Ui.ProviderChooserSurface {
            id: surface
            property string readState: "loading"
            property string readText: "Loading items…"
            property string operationStatus: ""
            property int saves: 0
            chooserController: Ui.ProviderChooserController {
                id: owner
                uiActive: true
                providerRankedResults: true
                closeDetailsWithoutSelection: true
                provider: Core.Provider { providerId: "state-test"; displayName: "State test" }
            }
            listComponent: Ui.ChooserListPane {
                chooserController: owner
                resultModel: owner.filteredResultsModel
                filterText: owner.filterText
                emptyIcon: "apps"
                emptyText: surface.readText
                emptyState: surface.readState
                powerVisible: false
                status: surface.operationStatus
                rowDelegate: Ui.ResultRow {
                    id: row
                    required property var resultData
                    listPane: surface.listItem
                    leadingIcon: "apps"
                    Ui.ResultLabel { title: row.resultData.title }
                }
            }
            detailsComponent: Item {
                Ui.TextField {
                    objectName: "stateTestEditor"
                    width: parent.width
                    text: "Saved"
                    onEdited: surface.saves++
                }
            }
        }
    }
    Component { id: appFactory; Apps.ApplicationListPane { width: 440; height: 600; controller: Apps.ApplicationController {} } }
    Component { id: clipFactory; Clipboard.ClipboardListPane { width: 440; height: 600; controller: Clipboard.ClipboardController {} } }
    Component { id: btFactory; Bluetooth.BluetoothDeviceListPane { width: 440; height: 600; controller: Bluetooth.BluetoothController {} } }
    Component { id: wifiFactory; Wifi.NetworkListPane { width: 440; height: 600; controller: Wifi.WifiController { prompt: Wifi.WifiPromptController {} } } }
    Component { id: displayFactory; Displays.DisplayListPane { width: 440; height: 600; controller: Displays.DisplayController {} } }
    Component { id: timeFactory; Activity.TimeWeatherListPane { width: 440; height: 600; controller: Activity.TimeWeatherController {} } }
    Component {
        id: systemFactory
        Bar.SystemChooserContent {
            controller: Bar.SystemChooserController {
                kind: "media"
                barController: Bar.BarController { surfaceRegistry: null }
            }
        }
    }
    Component { id: notificationsFactory; Activity.NotificationContent { controller: Activity.NotificationController {} } }
    Component { id: todoFactory; Activity.ActivityTodoSection { controller: Activity.ActivityController { rangeQueriesEnabled: false } uiScale: 1 } }
    Component { id: agendaFactory; Activity.ActivityAgendaPane { controller: Activity.ActivityController { rangeQueriesEnabled: false } } }
    Component { id: historyFactory; Battery.BatteryHistoryGraph { width: 420; points: [] } }
    Component { id: weatherFactory; Activity.WeatherHero { width: 420; weather: ({available: false}) } }

    function init(): void { failOnWarning(/.*/); calls = []; }
    function cleanup(): void { Quickshell.environment = ({}); }
    function stateOf(item) { return findChild(item, "resultListEmptyMessage"); }
    function backendOf(owner) { return owner.children.find(child => child instanceof Io.DaemonBackend) || owner.backend; }
    function pane(factory) {
        const item = createTemporaryObject(factory, testCase);
        verify(item !== null);
        tryVerify(() => stateOf(item) !== null);
        return item;
    }
    function test_semanticAndLegacyGlyphs_data() {
        return [
            {tag: "semantic", glyph: "content_paste", symbol: "content_paste"},
            {tag: "new-semantic", glyph: "calendar_month", symbol: "calendar_month"},
            {tag: "legacy", glyph: "󰂚", symbol: "notifications_none"},
            {tag: "specialist", glyph: "󰂲", symbol: ""}
        ];
    }
    function test_semanticAndLegacyGlyphs(data): void {
        const message = createTemporaryObject(messageFactory, testCase, {icon: data.glyph});
        const glyph = findChild(message, "contentStateGlyph");
        compare(glyph.symbol, data.symbol);
        compare(glyph.text, data.symbol || data.glyph);
        compare(message.Accessible.name, message.text);
        verify(glyph.Accessible.ignored);
        verify(!message.activeFocusOnTab);
        for (const kind of ["empty", "loading", "filtered", "unavailable", "disabled", "collecting"]) {
            message.kind = kind;
            compare(message.spinning, kind === "loading" && !Ui.Theme.noAnimations);
            message.active = false;
            verify(!message.spinning);
            message.active = true;
        }
        message.kind = "loading";
        message.visible = false;
        verify(!message.spinning);
        message.visible = true;
        message.showLabel = false;
        message.kind = "unavailable";
        verify(findChild(message, "contentStateLabel").visible, "failures keep visible words even in icon-only mode");
        compare(calls.length, 0);
    }
    function test_motionAndScalingStayPassive(): void {
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
        const message = createTemporaryObject(messageFactory, testCase, {kind: "loading"});
        verify(message.spinning);
        for (const scale of [1, 1.25, 2]) {
            message.uiScale = scale;
            compare(message.iconSize, 64 * scale);
            message.compact = true;
            compare(message.iconSize, 36 * scale);
            message.compact = false;
        }
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "true"};
        tryCompare(message, "spinning", false);
        compare(findChild(message, "contentStateBadge").rotation, 0);
        compare(message.badgeIcon, "refresh", "reduced motion keeps the static read cue and reason");
        verify(!message.activeFocus);
        compare(calls.length, 0);
    }
    function test_firstRowsDoNotStealFocusAndRefreshDoesNotCommitDrafts(): void {
        const surface = createTemporaryObject(surfaceFactory, testCase);
        tryVerify(() => surface.listItem !== null);
        const list = surface.listItem;
        const owner = surface.chooserController;
        const message = stateOf(surface);
        tryCompare(message, "visible", true);
        compare(message.kind, "loading");
        list.focusSearch();
        keyClick(Qt.Key_X);
        compare(owner.filterText, "x");
        const rows = owner.provider.resultsFor([{id: "one", title: "First"}, {id: "two", title: "Second"}]);
        owner.replaceProviderResults(rows, false);
        tryCompare(list, "resultCount", 2);
        verify(list.searchFocused, "first read completion must not take search focus");
        verify(!message.visible && !message.spinning);
        keyClick(Qt.Key_Down);
        verify(list.listFocused);
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        verify(list.listFocused, "expansion remains action-free and keeps list focus");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const editor = findChild(surface, "stateTestEditor");
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        compare(editor.text, "Savedx");
        surface.readState = "unavailable";
        surface.readText = "Refresh failed";
        surface.operationStatus = "Capturing window…";
        owner.replaceProviderResults(rows.concat(owner.provider.resultsFor([{id: "three", title: "Third"}])), false);
        tryCompare(list, "resultCount", 3);
        verify(!message.visible);
        compare(editor.text, "Savedx");
        compare(surface.saves, 0, "rendering and appending must not commit local edits");
        keyClick(Qt.Key_Escape);
        compare(editor.text, "Saved");
        owner.replaceProviderResults([], false);
        tryCompare(message, "visible", true);
        tryCompare(owner, "detailsOpen", false);
        compare(message.kind, "unavailable");
        compare(message.text, "Refresh failed");
        compare(list.status, "Capturing window…", "placeholder cannot replace an operation's status");
        verify(findChild(message, "contentStateLabel").visible);
        list.focusSearch();
        keyClick(Qt.Key_Tab);
        verify(!message.activeFocus, "empty states never become navigation stops");
        compare(surface.saves, 0);
        compare(calls.length, 0);
    }
    function test_listAdapters_data() {
        return [
            {tag: "applications", factory: appFactory, icon: "apps", loading: {"query-test": true}, error: "catalogError"},
            {tag: "clipboard", factory: clipFactory, icon: "content_paste", loading: {}, error: "historyReadError"},
            {tag: "bluetooth", factory: btFactory, icon: "bluetooth", loading: {snapshot: true}, error: "listError"},
            {tag: "wifi", factory: wifiFactory, icon: "wifi", loading: {networks: true}, error: "networksError"},
            {tag: "displays", factory: displayFactory, icon: "monitor", loading: {"display-snapshot-99": true}, error: "displayPolicyError"},
            {tag: "time-weather", factory: timeFactory, icon: "cloud", loading: {"activity-snapshot": true}, error: "snapshotReadError"}
        ];
    }
    function test_listAdapters(data): void {
        const list = pane(data.factory);
        const owner = list.controller;
        // Drive the real read facts without invoking writes or depending on a
        // daemon reply's timing. Independent operation busy is not list loading.
        backendOf(owner).pending = data.loading;
        if (data.tag === "clipboard") owner.activeHistoryQueryId = "query-current";
        tryCompare(list, "emptyState", "loading");
        const message = stateOf(list);
        compare(message.icon, data.icon);
        owner[data.error] = "Owned read failed";
        tryCompare(message, "kind", "unavailable");
        compare(message.text, "Owned read failed");
        list.status = "Unrelated operation completed";
        compare(message.text, "Owned read failed", "an unrelated operation cannot clear a read failure");
    }
    function test_settledAndPendingSearchAreDifferent(): void {
        const clip = pane(clipFactory);
        clip.controller.historyRevision = "settled-revision";
        compare(clip.emptyState, "empty");
        compare(clip.emptyText, "Clipboard history is empty");
        clip.controller.filterText = "unmatched";
        compare(clip.emptyText, "Waiting for search…");
        clip.controller.activeHistoryQueryId = "query-current";
        compare(clip.emptyState, "loading");
        clip.controller.activeHistoryQueryId = "";
        clip.controller.historyQueryText = "unmatched";
        compare(clip.emptyState, "filtered");
        compare(clip.emptyText, "No matching clipboard items");
        clip.controller.screenshotInFlight = true;
        compare(clip.emptyState, "filtered", "screenshot activity must not masquerade as loading");
        clip.controller.historyReadError = "Read failed";
        clip.controller.applyHistory("superseded", {snapshot_revision: "old", entries: [], total: 0});
        compare(clip.emptyText, "Read failed", "an obsolete read must not clear the current failure");
        const cities = pane(timeFactory);
        cities.controller.applySnapshot({activity: {available: true, syncing: false, world_clocks: []}});
        cities.controller.backend.pending = {};
        compare(cities.emptyText, "No configured cities");
        cities.controller.activity = {available: true, syncing: false, world_clocks: [{timezone: "Europe/London", label: "London"}]};
        cities.controller.filterText = "unmatched";
        compare(cities.emptyState, "filtered");
        compare(cities.emptyText, "No matching cities");
    }
    function test_radioOffIsNotDisconnectedOrMissingHardware(): void {
        const bt = pane(btFactory);
        const owner = bt.controller;
        backendOf(owner).pending = {};
        owner.backendAvailable = true;
        owner.radio = {available: true, adapter_count: 1, powered: false, operational: false};
        compare(bt.emptyState, "disabled");
        verify(bt.emptyIcon !== "bluetooth");
        owner.radio = {available: true, adapter_count: 1, powered: true, operational: true};
        compare(bt.emptyState, "empty");
        compare(bt.emptyIcon, "bluetooth");
        owner.radio = {available: false, adapter_count: 0};
        compare(bt.emptyText, "No Bluetooth adapters");
        compare(bt.emptyIcon, "bluetooth");
        backendOf(owner).applyUnhandledEvent({event: "loading"});
        compare(bt.emptyState, "loading", "daemon loading events are not failures");
        backendOf(owner).applyUnhandledEvent({event: "unavailable"});
        compare(bt.emptyState, "unavailable");
        owner.handleScanEvent({request_id: "scan-test", state: "failed", error: {message: "Discovery failed"}});
        compare(bt.emptyText, "Discovery failed");
        owner.handleScanEvent({request_id: "scan-retry", state: "running"});
        compare(bt.emptyState, "loading");

        const wifi = pane(wifiFactory);
        wifi.controller.backend.pending = {};
        wifi.controller.networksLoaded = true;
        wifi.controller.activeStatus = {radios: {wireless_available: true, wireless_enabled: false, wireless_hardware_enabled: true}};
        compare(wifi.emptyState, "disabled");
        compare(wifi.emptyIcon, "wifi_off");
        wifi.controller.activeStatus = {radios: {wireless_available: false, wireless_enabled: false, wireless_hardware_enabled: true}};
        compare(wifi.emptyText, "No Wi-Fi adapter");
        compare(wifi.emptyIcon, "wifi");
        wifi.controller.scan.applyEvent({event: "failed", message: "Scan failed"});
        compare(wifi.emptyState, "unavailable");
        compare(wifi.emptyText, "Scan failed");
    }
    function test_systemChoosersKeepRealRowsAndTrayHasNoSyntheticLoading(): void {
        const surface = pane(systemFactory);
        const owner = surface.controller;
        owner.uiActive = true;
        const desktop = owner.barController;
        desktop.backend.pending = {"snapshot-99": true};
        compare(stateOf(surface).kind, "loading");
        compare(stateOf(surface).icon, "music_note");
        desktop.media = {available: true, players: [{id: "one", identity: "Player", playback_status: "Paused"}]};
        tryCompare(surface.listItem, "resultCount", 1);
        verify(!stateOf(surface).visible, "paused player remains content during refresh");
        owner.kind = "audio";
        desktop.audio = {available: true, sink_name: "speakers", muted: true, volume_percent: 0};
        tryCompare(surface.listItem, "resultCount", 1);
        verify(!stateOf(surface).visible, "muted devices are not absent");
        owner.kind = "tray";
        tryCompare(surface.listItem, "resultCount", 0);
        compare(stateOf(surface).kind, "empty");
        compare(stateOf(surface).text, "No tray applications");
        desktop.backend.snapshotError = "Unrelated daemon failure";
        compare(stateOf(surface).kind, "empty");
    }
    function test_notificationFailureDoesNotLookLikeQuietHistory(): void {
        const surface = pane(notificationsFactory);
        const state = surface.controller.notificationState;
        state.notifications = {available: true};
        const catalog = surface.controller.catalog;
        catalog.rootBusy = true;
        compare(stateOf(surface).kind, "loading");
        catalog.rootBusy = false;
        catalog.loaded = true;
        compare(stateOf(surface).kind, "empty");
        catalog.rootError = "History read failed";
        compare(stateOf(surface).kind, "unavailable");
        compare(stateOf(surface).text, "History read failed");
        catalog.rootError = "";
        state.notifications = {available: true, dnd: true};
        compare(stateOf(surface).kind, "empty");
        compare(stateOf(surface).icon, "notifications_none");
    }
    function test_sectionsRetainUsefulControlsAndPartialData(): void {
        const todo = createTemporaryObject(todoFactory, testCase);
        const todoState = findChild(todo, "todoContentState");
        verify(todoState.visible);
        verify(findChild(todo, "activityTodoDraft").visible);
        const agenda = createTemporaryObject(agendaFactory, testCase);
        const agendaState = findChild(agenda, "agendaContentState");
        agenda.controller.rangeLoading = true;
        compare(agendaState.kind, "loading");
        agenda.controller.events = [{id: "one", title: "Meeting", start_unix_ms: agenda.controller.selectedDate.getTime(), end_unix_ms: agenda.controller.selectedDate.getTime() + 3600000}];
        verify(!agendaState.visible, "existing events remain visible during sync");
        const history = createTemporaryObject(historyFactory, testCase);
        const historyState = findChild(history, "historyEmptyLabel");
        compare(historyState.kind, "empty");
        history.currentPercentage = 60;
        compare(historyState.kind, "collecting");
        verify(!historyState.spinning, "accumulating history is not an endless request");
        const weather = createTemporaryObject(weatherFactory, testCase);
        const weatherState = findChild(weather, "weatherContentState");
        verify(weatherState.visible);
        weather.updating = true;
        compare(weatherState.kind, "loading");
        weather.weather = {available: false, temperature_c: 18, error: "Forecast refresh failed"};
        verify(!weatherState.visible, "cached temperature must not be blanked by a failed refresh");
        verify(findChild(weather, "weatherHeroTemperature").visible);
    }
}
