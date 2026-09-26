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
            property alias shortcut: actionShortcut
            chooserController: Ui.ChooserController {
                uiActive: true
            }
            listComponent: Component {
                Item {}
            }
            detailsComponent: Component {
                Item {}
            }
            detailsTabHelp: ""
            helpShortcuts: [actionShortcut]
            Ui.SurfaceShortcut {
                id: actionShortcut
                sequence: "Ctrl+J"
                help: "Do the action"
                onActivated: surface.activations++
            }
        }
    }

    function init() {
        failOnWarning(/.*/);
    }

    function test_helpTracksShortcutEditsAndListReplacement() {
        const surface = createTemporaryObject(surfaceComponent, testCase);
        verify(surface !== null);
        compare(surface.allHelpEntries.length, 1);
        compare(surface.allHelpEntries[0].keys, "Ctrl+J");
        compare(surface.allHelpEntries[0].action, "Do the action");
        wait(0);
        keyClick(Qt.Key_J, Qt.ControlModifier);
        compare(surface.activations, 1);

        surface.shortcut.sequence = "Ctrl+K";
        surface.shortcut.help = "Changed action";
        compare(surface.allHelpEntries[0].keys, "Ctrl+K");
        compare(surface.allHelpEntries[0].action, "Changed action");
        keyClick(Qt.Key_K, Qt.ControlModifier);
        compare(surface.activations, 2);
        surface.shortcut.help = "";
        compare(surface.allHelpEntries.length, 0);
        surface.shortcut.help = "Restored";
        compare(surface.allHelpEntries.length, 1);
        surface.helpShortcuts = [];
        compare(surface.allHelpEntries.length, 0);
        surface.helpShortcuts = [surface.shortcut];
        compare(surface.allHelpEntries[0].action, "Restored");
        surface.destroy();
        wait(0);
    }
}
