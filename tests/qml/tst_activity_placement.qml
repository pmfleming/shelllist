import QtQuick
import QtTest
import Shelllist.Activity as Activity
import Shelllist.Ui as Ui
import "../../qml/Shelllist/Io/HyprlandWorkArea.js" as WorkArea

TestCase {
    id: testCase
    name: "ActivityPlacement"
    Component { id: timeWeatherComponent; Activity.TimeWeatherController {} }

    function test_timeWeatherDoesNotInheritAgendaPlacement() {
        const controller = createTemporaryObject(timeWeatherComponent, testCase);
        verify(controller !== null);
        compare(controller.surfaceAlignment, "center");
        verify(!controller.surfaceFitsWorkspace);
        compare(controller.surfaceTopInset, 0);
        compare(controller.surfaceBottomInset, 0);
        compare(controller.surfaceHeightRatio, Ui.Theme.popupHeightRatio);
    }
    function test_logicalGeometry_data() {
        return [
            { tag: "fractional-laptop", margins: {left: 2, top: 53, right: 2, bottom: 2}, screen: {x: 0, y: 0, width: 1536, height: 960},
                expected: {x: 2, y: 53, width: 1532, height: 905, left: 2, top: 53, right: 2, bottom: 2} },
            { tag: "hidpi-negative-origin", margins: {left: 26, top: 82, right: 12, bottom: 22}, screen: {x: -1920, y: -100, width: 1920, height: 1080},
                expected: {x: -1894, y: -18, width: 1882, height: 976, left: 26, top: 82, right: 12, bottom: 22} },
            { tag: "portrait", margins: {left: 26, top: 82, right: 12, bottom: 22}, screen: {x: 1536, y: 0, width: 1080, height: 1920},
                expected: {x: 1562, y: 82, width: 1042, height: 1816, left: 26, top: 82, right: 12, bottom: 22} }
        ];
    }
    function test_logicalGeometry(data) {
        compare(WorkArea.rectangle(data.screen, data.margins), data.expected);
    }
    function test_missingMonitorAndSmallScreen() {
        compare(WorkArea.rectangle({width: 20, height: 30}, null), null);
        compare(WorkArea.rectangle({x: 0, y: 0, width: 20, height: 30}, {left: 40, top: 40, right: 40, bottom: 40}),
            {x: 19, y: 29, width: 1, height: 1, left: 19, top: 29, right: 0, bottom: 0});
    }
    function test_noFrontendCompositorParser() {
        compare(WorkArea.parseBatch, undefined);
        compare(WorkArea.workspaceMatches, undefined);
        compare(WorkArea.insets, undefined);
    }
}
