import QtQuick
import QtTest
import "../../qml/Shelllist/Io/HyprlandWorkArea.js" as WorkArea

TestCase {
    name: "ActivityPlacement"
    function test_logicalGeometry_data() {
        return [
            {
                tag: "hidpi-negative-origin",
                margins: {
                    left: 26,
                    top: 82,
                    right: 12,
                    bottom: 22
                },
                screen: {
                    x: -1920,
                    y: -100,
                    width: 1920,
                    height: 1080
                },
                expected: {
                    x: -1894,
                    y: -18,
                    width: 1882,
                    height: 976,
                    left: 26,
                    top: 82,
                    right: 12,
                    bottom: 22
                }
            }
        ];
    }
    function test_logicalGeometry(data) {
        compare(WorkArea.rectangle(data.screen, data.margins), data.expected);
    }
    function test_missingMonitorAndSmallScreen() {
        compare(WorkArea.rectangle({
            width: 20,
            height: 30
        }, null), null);
        compare(WorkArea.rectangle({
            x: 0,
            y: 0,
            width: 20,
            height: 30
        }, {
            left: 40,
            top: 40,
            right: 40,
            bottom: 40
        }), {
            x: 19,
            y: 29,
            width: 1,
            height: 1,
            left: 19,
            top: 29,
            right: 0,
            bottom: 0
        });
    }
}
