import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "PopoverHeight"

    Component {
        id: geometryFactory
        Ui.PopoverGeometry {}
    }

    function test_height_data() {
        return [
            {tag: "laptop125PercentWithBar", available: 909, expected: 818},
            {tag: "largeScreenPreviousCapThreshold", available: 1200, expected: 900},
            {tag: "largeScreen", available: 1440, expected: 900},
            {tag: "minimum", available: 390, expected: 360},
            {tag: "emergency", available: 300, expected: 284},
            {tag: "tiny", available: 1, expected: 1}
        ];
    }

    function test_height(data) {
        const geometry = createTemporaryObject(geometryFactory, testCase, {
            availableWidth: 1536,
            availableHeight: data.available
        });
        verify(geometry !== null);
        compare(geometry.height, data.expected);
        compare(geometry.y, Math.max(geometry.edgeMargin, Math.round((data.available - data.expected) / 2)));
        verify(geometry.y + geometry.height <= data.available - geometry.edgeMargin);
    }
}
