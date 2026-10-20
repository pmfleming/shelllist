import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "TimezoneClock"
    when: windowShown
    visible: true
    width: 400
    height: 100
    function test_visibleClockTracksAcknowledgedOffsetWithoutRestart() {
        const factory = Qt.createComponent(Qt.resolvedUrl("../../qml/Shelllist/Bar/BarClockButton.qml"));
        compare(factory.status, Component.Ready, factory.errorString());
        const button = createTemporaryObject(factory, testCase, {
            layoutDensity: 0, height: 40,
            now: new Date("2026-12-31T23:45:00Z"),
            timezone: {available: true, abbreviation: "MST", utc_offset_seconds: -25200}
        });
        verify(button !== null);
        const time = findChild(button, "barClock");
        const date = findChild(button, "barClockDate");
        compare(time.text, "16:45");
        compare(date.text, "12-31");
        button.timezone = {available: true, abbreviation: "NPT", utc_offset_seconds: 20700};
        compare(time.text, "05:30");
        compare(date.text, "01-01");
        verify(button.accessibleName.indexOf("2027-01-01 05:30 NPT +0545") >= 0);
        // Location confirmation can be pending without invalidating observed time.
        button.timezone = {available: true, abbreviation: "NPT", utc_offset_seconds: 20700,
            error: "IP confirmation unavailable · timezone unchanged · retrying automatically"};
        compare(time.text, "05:30");
        compare(date.text, "01-01");
        verify(button.descriptor.tooltip.indexOf("Timezone unavailable") < 0);
        verify(button.accessibleName.indexOf("2027-01-01 05:30 NPT +0545") >= 0);
    }
}
