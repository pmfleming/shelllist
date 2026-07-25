import QtQuick
import QtTest
import "../../qml/Shelllist/Ui/SegmentedNavigation.js" as Navigation

TestCase {
    name: "SegmentedNavigation"

    readonly property var options: [
        { value: "first" },
        { value: "second", enabled: false },
        { value: "third" }
    ]

    function test_skipsDisabledOptions() {
        compare(Navigation.nextEnabledIndex(options, 0, 1), 2);
    }

    function test_stopsAtBoundary() {
        compare(Navigation.nextEnabledIndex(options, 2, 1), -1);
    }

    function test_startsFromDirectionalEdge() {
        compare(Navigation.nextEnabledIndex(options, -1, -1), 2);
        compare(Navigation.nextEnabledIndex(options, -1, 1), 0);
    }

    function test_reportsOptionAvailability() {
        verify(Navigation.optionEnabled(options, 0));
        verify(!Navigation.optionEnabled(options, 1));
        verify(!Navigation.optionEnabled(options, 9));
    }
}
