import QtQuick
import Shelllist.Ui as Ui

ActivityController {
    id: controller

    property string detailsTab: "time"
    property string filterText: ""
    property double currentTimeMs: 0
    screenshotStartMessage: "Capturing Time & Weather window…"
    rangeQueriesEnabled: false
    readonly property var cities: combinedCities()
    readonly property var filteredCities: filterCities(cities, filterText)
    readonly property alias cityModel: cityListModel
    readonly property var selectedCity: filteredCities.length > 0 ? filteredCities[Math.max(0, Math.min(citySelection.selectedIndex, filteredCities.length - 1))] : ({})

    hasSelection: filteredCities.length > 0
    selectionModel: citySelection
    detailSection: "weather"
    weatherLocationId: selectedCity.weather ? String(selectedCity.weather.id || "") : ""
    closedWidthFraction: 0
    openWidthFraction: 0
    minimumClosedWindowWidth: Ui.Theme.popupClosedWidth
    maximumClosedWindowWidth: Ui.Theme.popupClosedWidth
    minimumOpenWindowWidth: Ui.Theme.popupOpenWidth
    maximumOpenWindowWidth: Ui.Theme.popupOpenWidth
    surfaceHeightRatio: Ui.Theme.popupHeightRatio
    surfaceFitsWorkspace: false
    surfaceAlignment: "center"

    function clocksByTimezone(clocks: var): var {
        const indexed = ({});
        clocks.forEach(function (clock) {
            indexed[String(clock.timezone || "")] = clock;
        });
        return indexed;
    }

    function offset(primary: var, fallback: var): real {
        if (primary !== undefined && primary !== null)
            return Number(primary);
        return fallback !== undefined && fallback !== null ? Number(fallback) : 0;
    }

    function firstPresent(values: var, fallback: var): var {
        const value = values.find(function (candidate) {
            return !!candidate;
        });
        return value || fallback;
    }

    function cityRecord(id: string, label: string, city: string, timezoneName: string, abbreviation: string, utcOffset: real, regionIds: var): var {
        return {
            id: id,
            label: label,
            city: city,
            timezone: timezoneName,
            abbreviation: abbreviation,
            utc_offset_seconds: utcOffset,
            timezone_region_ids: regionIds,
            latitude: 0,
            longitude: 0,
            has_coordinates: false,
            home: false,
            weather: null,
            has_weather: false,
            lunar: controller.activity.lunar || null
        };
    }

    function weatherCity(weather: var, index: int, clock: var): var {
        const timezoneName = String(firstPresent([weather.timezone], ""));
        const city = cityRecord("weather:" + String(firstPresent([weather.id], index)), String(firstPresent([weather.location, clock.label, clock.city], "Location")), String(firstPresent([clock.city, weather.location], "Location")), timezoneName, String(firstPresent([clock.abbreviation], "")), offset(weather.utc_offset_seconds, clock.utc_offset_seconds), firstPresent([weather.timezone_region_ids, clock.timezone_region_ids], []));
        const latitude = Number(weather.latitude);
        const longitude = Number(weather.longitude);
        city.has_coordinates = Number.isFinite(latitude) && Number.isFinite(longitude);
        city.latitude = city.has_coordinates ? latitude : 0;
        city.longitude = city.has_coordinates ? longitude : 0;
        city.home = !!weather.home;
        city.weather = weather;
        city.has_weather = true;
        return city;
    }

    function localCity(timezoneName: string, clock: var): var {
        const local = controller.timezone;
        const city = cityRecord("local:" + timezoneName, String(firstPresent([local.city, clock.label, clock.city], timezoneName)), String(firstPresent([local.city, clock.city], timezoneName)), timezoneName, String(firstPresent([local.abbreviation, clock.abbreviation], "")), Number(firstPresent([local.utc_offset_seconds], 0)), firstPresent([local.timezone_region_ids, clock.timezone_region_ids], []));
        city.home = true;
        return city;
    }

    function clockCity(clock: var, index: int): var {
        const timezoneName = String(firstPresent([clock.timezone], ""));
        return cityRecord("clock:" + timezoneName + ":" + index, String(firstPresent([clock.label, clock.city, timezoneName], "Location")), String(firstPresent([clock.city, clock.label, timezoneName], "Location")), timezoneName, String(firstPresent([clock.abbreviation], "")), Number(firstPresent([clock.utc_offset_seconds], 0)), firstPresent([clock.timezone_region_ids], []));
    }

    function appendWeatherCities(values: var, weatherValues: var, clockIndex: var, represented: var): void {
        weatherValues.forEach(function (weather, index) {
            const timezoneName = String(weather.timezone || "");
            values.push(weatherCity(weather, index, clockIndex[timezoneName] || ({})));
            if (timezoneName.length > 0) {
                represented[timezoneName] = true;
                delete clockIndex[timezoneName];
            }
        });
    }

    function appendLocalCity(values: var, clockIndex: var, represented: var): void {
        const timezoneName = String(controller.timezone.timezone || "");
        const alreadyHome = values.some(function (city) {
            return city.home;
        });
        if (!controller.timezone.available || timezoneName.length === 0 || represented[timezoneName] || alreadyHome)
            return;
        values.push(localCity(timezoneName, clockIndex[timezoneName] || ({})));
        represented[timezoneName] = true;
        delete clockIndex[timezoneName];
    }

    function appendClockCities(values: var, clocks: var, clockIndex: var): void {
        clocks.forEach(function (clock, index) {
            const timezoneName = String(clock.timezone || "");
            if (clockIndex[timezoneName]) {
                values.push(clockCity(clock, index));
                delete clockIndex[timezoneName];
            }
        });
    }

    function compareCities(left: var, right: var): int {
        if (left.home !== right.home)
            return left.home ? -1 : 1;
        return left.label.localeCompare(right.label);
    }

    function combinedCities(): var {
        const clocks = activity.world_clocks || [];
        const clockIndex = clocksByTimezone(clocks);
        const represented = ({});
        const values = [];
        appendWeatherCities(values, activity.weather_locations || [], clockIndex, represented);
        appendLocalCity(values, clockIndex, represented);
        appendClockCities(values, clocks, clockIndex);
        return values.sort(compareCities);
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
        const selectedId = selectedCity.id || "";
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
        detailsOpen = false;
        filterText = "";
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
