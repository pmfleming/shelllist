import QtQuick
import QtTest
import "../../qml/Shelllist/Bar/BarStatusPresentation.js" as Status

TestCase {
    id: testCase
    name: "TimezoneClock"
    when: windowShown
    visible: true
    width: 400
    height: 100
    function test_visibleButtonTracksOffsetAndDayImmediately() {
        const buttonFactory = Qt.createComponent(Qt.resolvedUrl("../../qml/Shelllist/Bar/BarClockButton.qml"));
        compare(buttonFactory.status, Component.Ready, buttonFactory.errorString());
        const button = createTemporaryObject(buttonFactory, testCase, {
            layoutDensity: 0, height: 40,
            now: new Date("2026-12-31T23:45:00Z"),
            timezone: {available: true, abbreviation: "MDT", utc_offset_seconds: -21600}
        });
        verify(button !== null);
        const timeLabel = findChild(button, "barClock");
        const dateLabel = findChild(button, "barClockDate");
        compare(timeLabel.text, "17:45");
        compare(dateLabel.text, "12-31");
        button.timezone = {available: true, abbreviation: "IST", utc_offset_seconds: 3600};
        compare(timeLabel.text, "00:45");
        compare(dateLabel.text, "01-01");
        verify(button.accessibleName.indexOf("2027-01-01 00:45 IST +0100") >= 0);
    }
    function test_networkTimezoneChangeNeedsNoProcessRestart() {
        const now = new Date("2026-10-14T15:39:00Z");
        const old = Status.clockModule(now, {available: true, abbreviation: "MDT", utc_offset_seconds: -21600});
        const current = Status.clockModule(now, {available: true, abbreviation: "IST", utc_offset_seconds: 3600});
        compare(old.text, "2026-10-14  09:39");
        compare(current.text, "2026-10-14  16:39");
        compare(current.compactText, "10-14 16:39");
        compare(current.tooltip, "2026-10-14 16:39 IST +0100");
        compare(current.primary, "time-weather");
    }
    function test_dayRolloverAndFractionalOffset() {
        const now = new Date("2026-12-31T23:45:00Z");
        compare(Status.clockModule(now, {utc_offset_seconds: 20700}).text, "2027-01-01  05:30");
        compare(Status.clockModule(new Date("2026-01-01T00:15:00Z"), {utc_offset_seconds: -3600}).text, "2025-12-31  23:15");
        compare(Status.clockModule(now, {utc_offset_seconds: 0}).text, "2026-12-31  23:45");
    }
    function test_unavailableOffsetDoesNotClaimUtcOrCachedZone() {
        const now = new Date("2026-10-14T15:39:00Z");
        for (const zone of [{}, {available: false, utc_offset_seconds: 0}, {utc_offset_seconds: NaN}]) {
            const result = Status.clockModule(now, zone);
            verify(result.tooltip.endsWith("Timezone unavailable"));
            compare(result.text, Qt.formatDateTime(now, "yyyy-MM-dd  HH:mm"));
        }
    }
}
