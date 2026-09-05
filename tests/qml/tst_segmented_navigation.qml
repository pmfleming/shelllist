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

    function test_navigatesEnabledOptionsAndBoundaries() {
        compare(Navigation.nextEnabledIndex(options, 0, 1), 2);
        compare(Navigation.nextEnabledIndex(options, 2, 1), -1);
        compare(Navigation.nextEnabledIndex(options, -1, -1), 2);
        compare(Navigation.nextEnabledIndex(options, -1, 1), 0);
    }

}
