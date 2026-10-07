pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "CompactFields"
    when: windowShown
    visible: true
    width: 640
    height: 720

    Component {
        id: factory
        Ui.PanelSurface {
            id: surface
            anchors.fill: undefined
            width: tests.width
            height: tests.height
            chooserController: Ui.ChooserController { uiActive: true }
            navigationContent: content
            property int writes: 0
            property string savedNote: "One line"
            property alias note: note
            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                Ui.FormField {
                    width: parent.width
                    label: "Note"
                    Ui.TextEditor {
                        id: note
                        objectName: "compactNote"
                        Layout.fillWidth: true
                        text: surface.savedNote
                        onEdited: function (value) { surface.savedNote = value; surface.writes++; }
                    }
                }
            }
        }
    }
    function init(): void { failOnWarning(/.*/); }
    function test_multilineGrowsAndTransactionsSurviveResize(): void {
        const surface = createTemporaryObject(factory, tests);
        verify(surface !== null);
        surface.detailsNavigation.focusContent(true);
        verify(waitForPolish(surface.Window.window));
        compare(surface.note.height, Ui.Theme.formHeight);
        mouseClick(surface.note, surface.note.width / 2, surface.note.height / 2);
        verify(surface.note.editSession.active);
        keyClick(Qt.Key_End, Qt.ControlModifier);
        for (let i = 0; i < 8; i++) {
            keyClick(Qt.Key_Return, Qt.ShiftModifier);
            keyClick(Qt.Key_X);
        }
        verify(waitForPolish(surface.Window.window));
        compare(surface.note.height, Ui.Theme.formTextAreaHeight);
        verify(surface.note.contentHeight > surface.note.height);
        compare(surface.writes, 0);
        surface.width = 340;
        verify(waitForPolish(surface.Window.window));
        verify(surface.note.editSession.active);
        keyClick(Qt.Key_Escape);
        compare(surface.note.text, "One line");
        verify(waitForPolish(surface.Window.window));
        compare(surface.note.height, Ui.Theme.formHeight);
        compare(surface.writes, 0);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Return);
        compare(surface.writes, 1);
        verify(surface.detailsNavigation.browsing);
    }
}
