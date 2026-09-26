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
            property int dismissals: 0
            property int f1Events: 0
            property alias shortcut: actionShortcut
            property alias search: searchField
            chooserController: Ui.ChooserController {
                uiActive: true
                onCloseWindowRequested: surface.dismissals++
            }
            listComponent: Component {
                Item {}
            }
            detailsComponent: Component {
                Item {}
            }
            Shortcut {
                id: actionShortcut
                sequence: "Ctrl+J"
                onActivated: surface.activations++
            }
            Ui.TextField {
                id: searchField
                width: 240
                height: 42
                onKeyPressed: function (event) {
                    if (event.key === Qt.Key_F1)
                        surface.f1Events++;
                    event.accepted = false;
                }
            }
        }
    }

    function init() {
        failOnWarning(/.*/);
    }

    function test_shortcutEditsAndDisabledState() {
        const surface = createTemporaryObject(surfaceComponent, testCase);
        verify(surface !== null);
        surface.search.focusInput(false);
        wait(0);
        keyClick(Qt.Key_J, Qt.ControlModifier);
        compare(surface.activations, 1);
        surface.shortcut.sequence = "Ctrl+K";
        keyClick(Qt.Key_K, Qt.ControlModifier);
        compare(surface.activations, 2);
        surface.shortcut.enabled = false;
        keyClick(Qt.Key_K, Qt.ControlModifier);
        compare(surface.activations, 2);
    }

    function test_noHelpShortcutStealsTextFocusOrEscape() {
        const surface = createTemporaryObject(surfaceComponent, testCase);
        verify(surface !== null);
        surface.search.focusInput(false);
        verify(surface.search.inputActiveFocus);
        wait(0);
        keyClick(Qt.Key_F1);
        compare(surface.f1Events, 1, "F1 reaches the focused control, not a help overlay");
        verify(surface.search.inputActiveFocus);
        keyClick(Qt.Key_Question);
        compare(surface.search.text, "?", "question marks remain ordinary query text");
        verify(surface.search.inputActiveFocus);
        surface.chooserController.detailsOpen = true;
        keyClick(Qt.Key_F1);
        keyClick(Qt.Key_Escape);
        compare(surface.chooserController.detailsOpen, false, "no hidden help layer consumes Escape");
        compare(surface.dismissals, 0);
        keyClick(Qt.Key_Escape);
        compare(surface.dismissals, 1);
    }
}
