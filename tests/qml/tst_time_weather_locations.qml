import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "TimeWeatherLocations"
    when: windowShown
    width: 1200; height: 700; visible: true
    Component { id: ownerFactory; Activity.TimeWeatherController {} }
    Component { id: contentFactory; Activity.TimeWeatherContent {} }
    function location(id, label) {
        return {id: id, label: label, city: label, timezone: "Etc/UTC", abbreviation: "UTC",
            utc_offset_seconds: 0, timezone_region_ids: [], has_coordinates: false, home: false,
            has_weather: false, weather: null, lunar: null};
    }
    function test_browseAndRetainNativeIdentityAcrossOrderingChanges() {
        const owner = createTemporaryObject(ownerFactory, testCase, {uiActive: true});
        owner.activity = {locations: [location("native-a", "Alpha"), location("native-b", "Beta")],
            world_clocks: [{timezone: "unexpected", label: "Must not synthesize"}]};
        const content = createTemporaryObject(contentFactory, testCase, {controller: owner, width: width, height: height});
        tryCompare(owner.cityModel, "count", 2);
        tryVerify(() => content.listItem !== null);
        content.listItem.focusList();
        keyClick(Qt.Key_Down);
        compare(owner.selectedCity.id, "native-b");
        owner.activity = {locations: [location("native-b", "Aardvark"), location("native-a", "Alpha")]};
        wait(0);
        compare(owner.selectedCity.id, "native-b", "retain native identity rather than an array index");
        keyClick(Qt.Key_Right);
        verify(owner.detailsOpen);
        content.destroy();
        wait(0);
    }
}
