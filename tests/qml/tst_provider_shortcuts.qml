import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "ProviderShortcuts"
    when: windowShown
    visible: true
    width: 640
    height: 400

    Component {
        id: surfaceComponent
        Ui.ProviderChooserSurface {
            id: surface
            width: 640
            height: 400
            property int activations: 0
            property alias screenshotShortcut: screenshotShortcut
            property alias search: searchField
            chooserController: Ui.ChooserController {
                uiActive: true
                onScreenshotRequested: surface.activations++
            }
            listComponent: Component {
                Item {}
            }
            detailsComponent: Component {
                Item {}
            }
            Ui.ScreenshotShortcut {
                id: screenshotShortcut
                controller: surface.chooserController
            }
            Ui.TextField {
                id: searchField
                width: 240
                height: 42
            }
        }
    }

    function init() {
        failOnWarning(/.*/);
    }

    Component {
        id: otherControllerComponent
        Ui.ChooserController {
            uiActive: true
            property int requests: 0
            onScreenshotRequested: requests++
        }
    }

    function test_screenshotTargetsCurrentViewWithoutStealingEditorFocus() {
        const surface = createTemporaryObject(surfaceComponent, testCase);
        verify(surface !== null);
        surface.search.focusInput(false);
        wait(0);
        keyClick(Qt.Key_S, Qt.AltModifier);
        compare(surface.activations, 1);
        verify(surface.search.inputActiveFocus);
        compare(surface.search.text, "");
        compare(surface.screenshotShortcut.autoRepeat, false);

        keyClick(Qt.Key_S, Qt.ControlModifier | Qt.ShiftModifier);
        compare(surface.activations, 1, "the old screenshot shortcut is removed");
        keyClick(Qt.Key_S);
        compare(surface.search.text, "s", "ordinary typing is unchanged");

        const other = createTemporaryObject(otherControllerComponent, testCase);
        surface.screenshotShortcut.controller = other;
        keyClick(Qt.Key_S, Qt.AltModifier);
        compare(other.requests, 1);
        compare(surface.activations, 1, "retained views must not capture");
        other.uiSuspending = true;
        keyClick(Qt.Key_S, Qt.AltModifier);
        compare(other.requests, 1);
        other.uiSuspending = false;
        other.uiActive = false;
        keyClick(Qt.Key_S, Qt.AltModifier);
        compare(other.requests, 1, "hidden views must not capture");
        surface.screenshotShortcut.controller = null;
        keyClick(Qt.Key_S, Qt.AltModifier);
        compare(other.requests, 1);
    }

}
