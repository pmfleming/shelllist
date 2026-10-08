import QtQuick
import Shelllist.Ui as Ui

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
    property double currentTimeMs: 0
    screenshotStartMessage: "Capturing Time & Weather window…"
    rangeQueriesEnabled: false
    readonly property var cities: (activity.locations || []).slice().sort(compareCities)
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

    function rebuildCityModel(): void {
        const previous = citySelection.selectedIndex >= 0 && citySelection.selectedIndex < cityListModel.count
            ? cityListModel.get(citySelection.selectedIndex).resultData.payload : selectedCity;
        const selectedId = previous.id || "";
        cityListModel.clear();
        filteredCities.forEach(function (city) {
            cityListModel.append({
                resultData: {
                    payload: city
                }
            });
        });
        const retained = filteredCities.findIndex(function (city) {
            return city.id === selectedId;
        });
        citySelection.selectedIndex = retained >= 0 ? retained : Math.max(0, Math.min(citySelection.selectedIndex, filteredCities.length - 1));
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
        Qt.callLater(rebuildCityModel);
    }

    function deactivateUi(): void {
        deactivateUiState();
        screenshotStatus = "";
    }

    onCitiesChanged: Qt.callLater(rebuildCityModel)
    Component.onCompleted: {
        currentTimeMs = Date.now();
        rebuildCityModel();
    }

    QtObject {
        id: citySelection
        property int selectedIndex: 0
        property string queryText: ""

        function move(delta: int): void {
            selectedIndex = Math.max(0, Math.min(selectedIndex + delta, controller.filteredCities.length - 1));
        }
        function selectFirst(): void {
            selectedIndex = 0;
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

    Timer {
        interval: 30000
        repeat: true
        running: controller.uiActive
        onTriggered: controller.currentTimeMs = Date.now()
    }

    ListModel {
        id: cityListModel
        dynamicRoles: true
    }
}
