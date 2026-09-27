pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "DomainWorkflows"
    when: windowShown
    visible: true
    width: 1100
    height: 650
    Component {
        id: panelFactory
        Ui.PanelSurface {
            chooserController: Ui.ChooserController {
                id: owner
                uiActive: true
                viewMemory: Ui.ChooserMemory {
                    controller: owner
                    key: "settings::test"
                    tab: "settings"
                    tabs: ["settings"]
                    presentationOpen: true
                }
            }
            Ui.DetailFlickable {
                anchors.fill: parent
                viewMemory: owner.viewMemory
                memoryTab: "settings"
                Ui.TextField { objectName: "ordinary"; width: parent.width; text: "ordinary value" }
                Ui.TextEditor { objectName: "multiline"; width: parent.width; height: 100; text: "line one\nline two" }
            }
        }
    }
    Component {
        id: activityFactory
        Activity.ActivityContent { controller: Activity.ActivityController {} }
    }
    function init() { failOnWarning(/.*/); }
    function test_panelRestoresEditorButNeverItsValue() {
        const panel = createTemporaryObject(panelFactory, testCase);
        const owner = panel.chooserController;
        owner.restoreUiFocus();
        tryVerify(() => panel.detailsNavigation.browsing);
        keyClick(Qt.Key_Right);
        const field = findChild(panel, "ordinary");
        tryVerify(() => field.inputActiveFocus);
        field.restoreSelection({anchor: 8, cursor: 2});
        owner.deactivateUi();
        panel.forceActiveFocus();
        field.text = "short";
        owner.activateUi("");
        owner.restoreUiFocus();
        tryVerify(() => field.inputActiveFocus);
        compare(field.text, "short");
        compare(field.selectionState().cursor, 2);
        compare(field.selectionState().anchor, 5);
        verify(!JSON.stringify(owner.focusMemory).includes("ordinary value"));
        keyClick(Qt.Key_Escape);
        verify(panel.detailsNavigation.browsing);
    }
    function test_multilineArrowsAndEscapeStayNativeUntilRetreat() {
        const panel = createTemporaryObject(panelFactory, testCase);
        panel.chooserController.restoreUiFocus();
        tryVerify(() => panel.detailsNavigation.browsing);
        keyClick(Qt.Key_Down);
        compare(panel.detailsNavigation.currentTarget.objectName, "multiline");
        keyClick(Qt.Key_Right);
        const editor = findChild(panel, "multiline");
        verify(editor.activeFocus);
        editor.cursorPosition = 4;
        keyClick(Qt.Key_Left);
        compare(editor.cursorPosition, 3);
        keyClick(Qt.Key_Escape);
        verify(panel.detailsNavigation.browsing);
        compare(editor.text, "line one\nline two");
    }
    function test_activityTypingDoesNotInvokeFormerLetterShortcuts() {
        const panel = createTemporaryObject(activityFactory, testCase);
        panel.controller.uiActive = true;
        panel.controller.openSection("schedule");
        tryVerify(() => findChild(panel, "activityTodoDraft") !== null);
        const field = findChild(panel, "activityTodoDraft");
        field.focusInput(false);
        keyClick(Qt.Key_T);
        keyClick(Qt.Key_1);
        compare(panel.controller.todoDraft, "t1");
        compare(field.text, "t1");
        panel.controller.deactivateUi();
        compare(panel.controller.todoDraft, "t1");
    }
}
