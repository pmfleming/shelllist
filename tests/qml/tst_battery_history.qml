import QtQuick
import QtTest
import Shelllist.Battery as Battery
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "BatteryHistory"
    when: windowShown
    visible: true
    width: 540
    height: 720

    Component {
        id: edgeGraph
        Battery.BatteryHistoryGraph {
            id: fixture
            property int dismissals: 0
            Ui.ChooserController {
                id: controller
                uiActive: true
                onCloseWindowRequested: fixture.dismissals++
            }
            Ui.ChooserShortcuts {
                controller: controller
            }
            width: 300
            height: graphHeight
            points: [
                {
                    timestamp_ms: 1000,
                    active_time_ms: 0,
                    percentage: 100,
                    continuous: false
                },
                {
                    timestamp_ms: 61000,
                    active_time_ms: 60000,
                    percentage: 0,
                    continuous: false
                }
            ]
        }
    }

    function test_valuesRequireExplicitInspectionAndEscapeStaysLocal() {
        const graph = createTemporaryObject(edgeGraph, testCase);
        verify(graph !== null);
        verify(waitForRendering(graph));
        const readout = findChild(graph, "batteryHistoryInspection");
        const plot = findChild(graph, "batteryHistoryPlot");
        verify(readout !== null);
        graph.hovered(0.4);
        verify(!readout.visible, "hover never reveals text");
        graph.forceActiveFocus();
        verify(!readout.visible, "focus never reveals text");
        keyClick(Qt.Key_Right);
        verify(readout.visible);
        keyClick(Qt.Key_Home);
        compare(graph.inspectionPosition, 0);
        verify(readout.text.includes("100%"));
        keyClick(Qt.Key_Left);
        compare(graph.inspectionPosition, 0, "inspection stays in bounds");
        keyClick(Qt.Key_End);
        compare(graph.inspectionPosition, 1);
        verify(readout.text.includes("0%"));
        keyClick(Qt.Key_Escape);
        verify(!readout.visible);
        compare(graph.dismissals, 0, "editor Escape wins over the surface shortcut");
        keyClick(Qt.Key_Escape);
        compare(graph.dismissals, 1);
        mouseClick(plot, plot.width / 2, plot.height / 2);
        verify(readout.visible, "click also explicitly requests values");
        verify(graph.activeFocus);
    }
}
