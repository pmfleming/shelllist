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
    function test_unavailableOffsetDoesNotClaimUtcOrCachedZone() {
        const now = new Date("2026-10-14T15:39:00Z");
        for (const zone of [{}, {available: false, utc_offset_seconds: 0}, {utc_offset_seconds: NaN}]) {
            const result = Status.clockModule(now, zone);
            verify(result.tooltip.endsWith("Timezone unavailable"));
            compare(result.text, Qt.formatDateTime(now, "yyyy-MM-dd  HH:mm"));
        }
    }
}
