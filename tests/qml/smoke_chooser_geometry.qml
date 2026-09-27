pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

// PanelWindow and input masks require a real Wayland backend. Exercise the
// shared visual bounds in an offscreen floating window; input/layer QA is live.
ShellRoot {
    id: smoke
    property real initialX: 0
    property int initialHeight: 0
    property int phase: 0

    Ui.ChooserController {
        id: controller
        hasSelection: true
        availableScreenWidth: window.screen ? window.screen.width : 1280
        availableScreenHeight: window.screen ? window.screen.height : 960
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: controller.geometry.surfaceWidth
        implicitHeight: controller.geometry.height
        color: "transparent"
        Ui.VisualSurface {
            id: visual
            contentWidth: Math.min(controller.currentWindowWidth, controller.geometry.surfaceWidth)
            canvasWidth: controller.currentWindowWidth
            minimumContentHeight: controller.geometry.minimumContentHeight
            loadWhen: true
            content: Component {
                Ui.ProviderChooserSurface {
                    chooserController: controller
                    listComponent: Component {
                        Ui.ChooserListPane {
                            chooserController: controller
                            powerVisible: false
                            rowDelegate: Component { Item {} }
                        }
                    }
                    detailsComponent: Component { Ui.DetailFlickable {} }
                }
            }
        }
    }
    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            if (smoke.phase++ === 0) {
                smoke.initialX = controller.geometry.x;
                smoke.initialHeight = window.height;
                if (visual.width !== controller.closedWindowWidth || visual.width >= window.width) {
                    console.error("Closed chooser visual must exclude reserved space");
                    Qt.exit(1);
                    return;
                }
                controller.openDetails();
                return;
            }
            if (!Number.isFinite(controller.geometry.x) || controller.geometry.x !== smoke.initialX || visual.x !== 0 || window.height !== smoke.initialHeight || visual.width > window.width || visual.width !== controller.geometry.surfaceWidth) {
                console.error("Native chooser visual geometry contract failed");
                Qt.exit(1);
                return;
            }
            Qt.quit();
        }
    }
}
