import QtQuick
import Shelllist.Ui as Ui

ActivityController {
    id: controller

    property string detailsTab: "time"
    property string filterText: ""
    property double currentTimeMs: Date.now()
    screenshotStartMessage: "Capturing Time & Weather window…"
    rangeQueriesEnabled: false
    notificationHistoryEnabled: false
    readonly property var cities: combinedCities()
    readonly property var filteredCities: filterCities(cities, filterText)
    readonly property alias cityModel: cityListModel
    readonly property var selectedCity: filteredCities.length > 0
        ? filteredCities[Math.max(0, Math.min(citySelection.selectedIndex,
            filteredCities.length - 1))] : ({})

    hasSelection: filteredCities.length > 0
    selectionModel: citySelection
    detailSection: "weather"
    closedWidthFraction: 0
    openWidthFraction: 0
    minimumClosedWindowWidth: Ui.Theme.popupClosedWidth
    maximumClosedWindowWidth: Ui.Theme.popupClosedWidth
    minimumOpenWindowWidth: Ui.Theme.popupOpenWidth
    maximumOpenWindowWidth: Ui.Theme.popupOpenWidth
    surfaceHeightRatio: Ui.Theme.popupHeightRatio
    surfaceTopInset: 0
    surfaceAlignment: "center"

    function combinedCities(): var {
        const weatherValues = activity.weather_locations || [];
        const clockValues = activity.world_clocks || [];
        const clockByTimezone = ({});
        clockValues.forEach(function (clock) {
            clockByTimezone[String(clock.timezone || "")] = clock;
        });

        const representedTimezones = ({});
        const values = weatherValues.map(function (weather, index) {
            const timezone = String(weather.timezone || "");
            const clock = clockByTimezone[timezone] || ({});
            const latitude = Number(weather.latitude);
            const longitude = Number(weather.longitude);
            const hasCoordinates = Number.isFinite(latitude)
                && Number.isFinite(longitude);
            if (timezone.length > 0) {
                representedTimezones[timezone] = true;
                delete clockByTimezone[timezone];
            }
            return {
                id: "weather:" + String(weather.id || index),
                label: String(weather.location || clock.label || clock.city || "Location"),
                city: String(clock.city || weather.location || "Location"),
                timezone: timezone,
                abbreviation: String(clock.abbreviation || ""),
                utc_offset_seconds: Number(weather.utc_offset_seconds !== undefined
                    && weather.utc_offset_seconds !== null ? weather.utc_offset_seconds
                    : (clock.utc_offset_seconds !== undefined
                        && clock.utc_offset_seconds !== null ? clock.utc_offset_seconds : 0)),
                timezone_region_ids: weather.timezone_region_ids
                    || clock.timezone_region_ids || [],
                latitude: hasCoordinates ? latitude : 0,
                longitude: hasCoordinates ? longitude : 0,
                has_coordinates: hasCoordinates,
                home: !!weather.home,
                weather: weather,
                has_weather: true
            };
        });

        const localTimezone = String(controller.timezone.timezone || "");
        if (controller.timezone.available && localTimezone.length > 0
                && !representedTimezones[localTimezone]
                && !values.some(function (city) { return city.home; })) {
            const localClock = clockByTimezone[localTimezone] || ({});
            values.push({
                id: "local:" + localTimezone,
                label: String(controller.timezone.city || localClock.label
                    || localClock.city || localTimezone),
                city: String(controller.timezone.city || localClock.city || localTimezone),
                timezone: localTimezone,
                abbreviation: String(controller.timezone.abbreviation
                    || localClock.abbreviation || ""),
                utc_offset_seconds: Number(controller.timezone.utc_offset_seconds || 0),
                timezone_region_ids: controller.timezone.timezone_region_ids
                    || localClock.timezone_region_ids || [],
                latitude: 0,
                longitude: 0,
                has_coordinates: false,
                home: true,
                weather: null,
                has_weather: false
            });
            representedTimezones[localTimezone] = true;
            delete clockByTimezone[localTimezone];
        }

        clockValues.forEach(function (clock, index) {
            const timezone = String(clock.timezone || "");
            if (!clockByTimezone[timezone])
                return;
            values.push({
                id: "clock:" + timezone + ":" + index,
                label: String(clock.label || clock.city || timezone || "Location"),
                city: String(clock.city || clock.label || timezone || "Location"),
                timezone: timezone,
                abbreviation: String(clock.abbreviation || ""),
                utc_offset_seconds: Number(clock.utc_offset_seconds || 0),
                timezone_region_ids: clock.timezone_region_ids || [],
                latitude: 0,
                longitude: 0,
                has_coordinates: false,
                home: false,
                weather: null,
                has_weather: false
            });
            delete clockByTimezone[timezone];
        });
        return values.sort(function (left, right) {
            if (left.home !== right.home)
                return left.home ? -1 : 1;
            return left.label.localeCompare(right.label);
        });
    }

    function filterCities(values: var, query: string): var {
        const needle = String(query || "").trim().toLowerCase();
        if (needle.length === 0)
            return values;
        return values.filter(function (city) {
            return [city.label, city.city, city.timezone, city.abbreviation,
                city.weather ? city.weather.condition : ""].join(" ")
                .toLowerCase().indexOf(needle) >= 0;
        });
    }

    function rebuildCityModel(): void {
        const selectedId = selectedCity.id || "";
        cityListModel.clear();
        filteredCities.forEach(function (city) {
            cityListModel.append({ resultData: { payload: city } });
        });
        const retained = filteredCities.findIndex(function (city) {
            return city.id === selectedId;
        });
        citySelection.selectedIndex = retained >= 0 ? retained
            : Math.max(0, Math.min(citySelection.selectedIndex,
                filteredCities.length - 1));
        syncWeatherSelection();
    }

    function syncWeatherSelection(): void {
        const weather = selectedCity.weather;
        weatherLocationId = weather ? String(weather.id || "") : "";
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
    Component.onCompleted: rebuildCityModel()

    QtObject {
        id: citySelection
        property int selectedIndex: 0
        property string queryText: controller.filterText

        function move(delta: int): void {
            selectedIndex = Math.max(0, Math.min(selectedIndex + delta,
                controller.filteredCities.length - 1));
        }
        function selectFirst(): void { selectedIndex = 0; }

        onSelectedIndexChanged: controller.syncWeatherSelection()
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
