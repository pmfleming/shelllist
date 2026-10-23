import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

ActivityController {
    id: controller

    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.selectedCity.id ? "time-weather::" + controller.selectedCity.id : ""
        tab: controller.detailsTab
        tabs: ["time", "weather"]
        onRestoreRequested: function (open, tab) {
            controller.detailsTab = tab;
            controller.detailsOpen = open && controller.hasSelection;
        }
    }
    function resultKeyAt(index: int): string {
        return filteredCities[index] ? "time-weather::" + filteredCities[index].id : "";
    }
    function resultIndexForKey(key: string): int {
        return filteredCities.findIndex(city => "time-weather::" + city.id === key);
    }
    property string detailsTab: "time"
    property string filterText: ""
    readonly property TimeWeatherLocations locations: TimeWeatherLocations { controller: controller }
    navigationBlocked: locations.modalOpen
    navigationPrimaryEnabled: true
    detailActions: [
        {id: "manual", label: qsTr("Set current location manually"), icon: "my_location", accessKey: "L", enabled: locations.canControl, presentation: {group: "primary"}},
        {id: "automatic", label: qsTr("Return to Automatic"), icon: "explore", accessKey: "R", enabled: locations.canAutomatic, presentation: {group: "toolbar"}},
        {id: "remove", label: qsTr("Remove city"), icon: "delete", accessKey: "D", enabled: locations.canRemove, presentation: {group: "toolbar", tone: "danger"}}
    ]
    function triggerDetailAction(actionId: string): void {
        if (actionId === "manual") locations.openPicker("manual");
        else if (actionId === "automatic") locations.returnAutomatic();
        else if (actionId === "remove") locations.askRemove();
    }
    screenshotStartMessage: "Capturing Time & Weather window…"
    rangeQueriesEnabled: false
    readonly property var cities: (activity.locations || []).filter(city => !city.current || city.home || WeatherVisuals.hasLocationClock(city)).sort(compareCities)
    readonly property var filteredCities: filterCities(cities, filterText)
    readonly property alias cityModel: cityListModel
    readonly property var selectedCity: filteredCities.length > 0 ? filteredCities[Math.max(0, Math.min(citySelection.selectedIndex, filteredCities.length - 1))] : ({})

    hasSelection: filteredCities.length > 0
    selectionModel: citySelection
    detailSection: "weather"
    weatherLocationId: selectedCity.weather ? String(selectedCity.weather.id || "") : ""

    function compareCities(left: var, right: var): int {
        if (left.home !== right.home)
            return left.home ? -1 : 1;
        return left.label.localeCompare(right.label);
    }

    function filterCities(values: var, query: string): var {
        const needle = String(query || "").trim().toLowerCase();
        if (needle.length === 0)
            return values;
        return values.filter(function (city) {
            return [city.label, city.city, city.timezone, city.abbreviation, city.weather ? city.weather.condition : ""].join(" ").toLowerCase().indexOf(needle) >= 0;
        });
    }

    property string retainedCityId: ""
    property bool rebuildingCities: false
    function rebuildCityModel(): void {
        const selectedId = retainedCityId;
        rebuildingCities = true;
        cityListModel.values = filteredCities.map(city => ({key: "time-weather::" + city.id, payload: city}));
        const retained = filteredCities.findIndex(function (city) {
            return city.id === selectedId;
        });
        const home = selectedId === "current-location" ? filteredCities.findIndex(city => city.home) : -1;
        if (retained < 0 && home >= 0 && viewMemory) {
            // This is the same effective location becoming Home, not an ordinary
            // result browse. Preserve the outgoing tab instead of restoring an
            // older Home tab (or the transient row at Current's old index).
            const outgoing = viewMemory.records["time-weather::current-location"];
            const tab = outgoing?.tab || detailsTab;
            const key = "time-weather::" + filteredCities[home].id;
            viewMemory.records[key] = Object.assign({pages: Object.create(null)}, viewMemory.records[key] || ({}), {tab: tab, open: detailsOpen});
            detailsTab = tab;
        }
        citySelection.selectedIndex = retained >= 0 ? retained : home >= 0 ? home : Math.max(0, Math.min(citySelection.selectedIndex, filteredCities.length - 1));
        retainedCityId = filteredCities[citySelection.selectedIndex]?.id || "";
        rebuildingCities = false;
    }

    function setDetailsTab(tab: string): void {
        if (["time", "weather"].indexOf(tab) >= 0)
            detailsTab = tab;
    }

    function cycleDetailsTab(): void {
        detailsTab = detailsTab === "time" ? "weather" : "time";
    }

    function primarySelected(): bool {
        if (!hasSelection)
            return false;
        openDetails();
        return true;
    }

    function activateUi(workspaceId): void {
        activateUiState(workspaceId);
        backend.snapshot();
        locations.readStatus();
        Qt.callLater(rebuildCityModel);
    }

    function deactivateUi(): void {
        locations.closeModal();
        deactivateUiState();
        screenshotStatus = "";
    }

    function refresh(): void {
        backend.refresh();
        locations.readStatus();
    }

    onCitiesChanged: Qt.callLater(rebuildCityModel)
    Component.onCompleted: rebuildCityModel()

    Core.SelectionModel {
        id: citySelection
        count: controller.filteredCities.length
        onSelectedIndexChanged: {
            if (!controller.rebuildingCities && selectedIndex >= 0 && selectedIndex < cityListModel.count)
                controller.retainedCityId = cityListModel.get(selectedIndex).resultData.payload.id || "";
        }

        onQueryTextChanged: {
            if (controller.filterText !== queryText)
                controller.filterText = queryText;
        }
    }

    onFilterTextChanged: {
        if (citySelection.queryText !== filterText)
            citySelection.queryText = filterText;
        rebuildCityModel();
    }

    Core.KeyedListModel {
        id: cityListModel
    }
}
