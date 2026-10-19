import QtQuick
import Shelllist.Activity as Activity
import Shelllist.Ui as Ui
import "../../activity/WeatherVisuals.js" as Visuals

DaemonTestCase {
    id: testCase
    name: "TimeWeatherEstimates"
    when: windowShown
    visible: true
    width: 1200
    height: 700
    Component { id: ownerFactory; Activity.TimeWeatherController {} }
    Component { id: contentFactory; Activity.TimeWeatherContent {} }

    function location(source, accuracy) {
        return {id: "current-location", label: "Current location", city: "Dublin",
            timezone: "Europe/Dublin", abbreviation: "IST", utc_offset_seconds: 3600,
            latitude: 53.3, longitude: -6.2, has_coordinates: true,
            has_weather: false, home: false, current: true,
            location_source: source, accuracy_meters: accuracy};
    }
    function test_estimateMetadataIsPassiveAndRetainsIdentity_data() {
        return [{tag: "normal-dark", scheme: Qt.Dark, panelWidth: 1200},
            {tag: "minimum-light", scheme: Qt.Light, panelWidth: 976}];
    }
    function test_estimateMetadataIsPassiveAndRetainsIdentity(data) {
        const oldScheme = Ui.Theme.previewColorScheme;
        Ui.Theme.previewColorScheme = data.scheme;
        const owner = createTemporaryObject(ownerFactory, testCase, {uiActive: true});
        const saved = Object.assign({}, location("ip", 26000), {id: "clock:saved", label: "Saved clock", current: false});
        owner.activity = Object.assign({}, owner.activity, {available: true, locations: [location("ip", 26000), saved]});
        const content = createTemporaryObject(contentFactory, testCase, {controller: owner, width: data.panelWidth, height: height});
        tryCompare(owner.cityModel, "count", 2);
        content.listItem.focusList();
        const rowName = "timeWeatherLocation::current-location";
        tryVerify(() => findChild(content, rowName) !== null);
        verify(findChild(content, rowName).accessibleName.indexOf("IP estimate · reported accuracy ~26 km") >= 0);
        keyClick(Qt.Key_Right);
        tryCompare(owner, "detailsExpansionProgress", 1);
        tryVerify(() => content.detailsNavigation.contentReady);
        verify(content.detailsItem.subtitle.indexOf("IP estimate · reported accuracy ~26 km") >= 0);
        compare(content.detailsNavigation.availableFields().length, 0);
        keyClick(Qt.Key_Tab);
        tryVerify(() => content.detailsNavigation.activeFocus);
        verify(!content.detailsNavigation.editing);
        const before = calls.length;
        owner.activity = Object.assign({}, owner.activity, {locations: [saved, location("future_gps", null)]});
        tryCompare(owner.selectedCity, "id", "current-location");
        tryVerify(() => content.detailsItem.subtitle.indexOf("source unknown") >= 0);
        verify(content.detailsItem.subtitle.indexOf("accuracy") < 0, "missing accuracy must not appear as zero");
        compare(content.detailsNavigation.availableFields().length, 0);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(!content.detailsNavigation.editing);
        keyClick(Qt.Key_Down);
        tryCompare(owner.selectedCity, "id", "clock:saved");
        verify(owner.detailsOpen);
        compare(content.detailsItem.subtitle, "Europe/Dublin");
        compare(calls.length, before, "metadata and browsing never publish settings");
        content.destroy();
        wait(0);
        Ui.Theme.previewColorScheme = oldScheme;
    }
    function test_forecastFailureKeepsClockAndInvalidTimezoneNeverBecomesUtc() {
        const owner = createTemporaryObject(ownerFactory, testCase, {uiActive: true});
        const city = Object.assign({}, location("ip", 26000), {
            has_weather: true, weather: {available: false, error: "Forecast unavailable", utc_offset_seconds: 0}
        });
        owner.activity = Object.assign({}, owner.activity, {available: true, locations: [city]});
        const content = createTemporaryObject(contentFactory, testCase, {controller: owner, width: width, height: height});
        const rowName = "timeWeatherLocation::current-location";
        tryVerify(() => findChild(content, rowName) !== null);
        const row = findChild(content, rowName);
        row.nowMs = Date.UTC(2026, 9, 19, 12, 26);
        compare(row.localTime(), "13:26");
        verify(row.clockAvailable);
        content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryCompare(owner, "detailsExpansionProgress", 1);
        tryVerify(() => findChild(content, "locationClockZone") !== null);
        compare(findChild(content, "locationClockZone").text, "IST  ·  UTC+1");
        compare(findChild(content, "locationClockTime").text, Visuals.localTime(content.now.getTime(), 3600));
        const before = calls.length;
        for (const invalid of [
            {timezone: "Invalid/Zone", clock_unavailable: true, utc_offset_seconds: 0},
            {timezone: "", utc_offset_seconds: 0},
            {utc_offset_seconds: undefined}
        ]) {
            owner.activity = Object.assign({}, owner.activity, {locations: [Object.assign({}, city, invalid)]});
            tryVerify(() => {
                const currentRow = findChild(content, rowName);
                return currentRow !== null && currentRow.clockAvailable === false;
            });
            compare(findChild(content, rowName).localTime(), "—");
            compare(findChild(content, "locationClockTime").text, "—");
            compare(findChild(content, "locationClockDate").text, "—");
            compare(findChild(content, "locationClockZone").text, "Timezone unavailable");
            verify(!findChild(content, "locationTimezoneMap").hasOceanBand);
            verify(content.detailsItem.subtitle.indexOf("Timezone unavailable") >= 0);
            compare(content.detailsNavigation.availableFields().length, 0);
        }
        owner.activity = Object.assign({}, owner.activity, {locations: [Object.assign({}, city, {
            timezone: "Etc/UTC", abbreviation: "UTC", utc_offset_seconds: 0
        })]});
        tryVerify(() => {
            const currentRow = findChild(content, rowName);
            return currentRow !== null && currentRow.clockAvailable === true;
        });
        const utcRow = findChild(content, rowName);
        utcRow.nowMs = Date.UTC(2026, 9, 19, 12, 26);
        compare(utcRow.localTime(), "12:26", "a real zero offset remains valid");
        compare(findChild(content, "locationClockZone").text, "UTC  ·  UTC");
        verify(findChild(content, "locationTimezoneMap").hasOceanBand);
        compare(calls.length, before, "clock presentation must not request weather or write settings");
        content.destroy();
        wait(0);
    }
    function test_missingInvalidAndNonIpAccuracyNeverInventPrecision() {
        for (const accuracy of [undefined, null, NaN, -1, "26000"])
            verify(Visuals.locationEstimate(location("non_ip", accuracy)).indexOf("accuracy") < 0);
        compare(Visuals.locationEstimate(location("non_ip", 800)), "Location estimate (non-IP) · reported accuracy ~800 m");
        compare(Visuals.locationEstimate(location("ip", 1500)), "IP estimate · reported accuracy ~1.5 km");
    }
}
