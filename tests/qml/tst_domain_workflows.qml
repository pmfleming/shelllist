pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity
import "../../qml/Shelllist/Io/HyprlandSettings.js" as CompositorSettings

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
        Activity.ActivityContent {
            id: activity
            property int unrelatedRequests: 0
            controller: Activity.ActivityController {
                onTimeWeatherRequested: activity.unrelatedRequests++
                onNotificationsRequested: activity.unrelatedRequests++
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    Component {
        id: iconActionFactory
        Ui.ActionButton { label: "Settings"; icon: "󰒓"; width: 42; height: 42 }
    }
    function test_iconActionsKeepTheirNonvisualName() {
        const button = createTemporaryObject(iconActionFactory, testCase);
        compare(button.Accessible.name, "Settings");
        compare(findChild(button, "actionLabel").label, "");
        button.iconOnly = false;
        compare(findChild(button, "actionLabel").label, "Settings");
    }
    function test_compositorPreferenceAndScopedBlurCommand() {
        verify(CompositorSettings.motionDisabled({int: 0}));
        verify(!CompositorSettings.motionDisabled({int: 1}));
        const command = CompositorSettings.layerStyle("shelllist.test", true, true);
        compare(command[0], "hyprctl");
        compare(command[1], "eval");
        verify(command[2].includes("blur = true"));
        verify(command[2].includes("no_anim = true"));
        verify(command[2].includes("ignore_alpha = 0.01"));
        verify(command[2].includes("^shelllist\\\\.test$"), "scope is a literal namespace, not an arbitrary regex");
    }
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
    function test_revealedSensitiveFieldsNeverHaveRestorableLocations() {
        const panel = createTemporaryObject(panelFactory, testCase);
        const field = findChild(panel, "ordinary");
        compare(Ui.FocusLocations.key(null), "");
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), field);
        const duplicate = createTemporaryObject(iconActionFactory, panel, {objectName: field.objectName, enabled: false});
        compare(Ui.FocusLocations.uniqueTarget([field, duplicate], field.focusKey), null);
        field.sensitive = true;
        field.password = false;
        compare(Ui.FocusLocations.uniqueTarget([field], field.focusKey), null);
        field.focusInput(false);
        compare(field.selectionState(), null);
        compare(Ui.FocusLocations.capture(panel, findChild(field, "fieldInput")), null);
        panel.detailsNavigation.currentTarget = field;
        compare(panel.detailsNavigation.locationState().target, "");
    }
    function test_activityContainsOnlyCalendarAgendaAndTodos() {
        const panel = createTemporaryObject(activityFactory, testCase);
        panel.controller.uiActive = true;
        panel.controller.selectDate(new Date(2026, 8, 10));
        panel.controller.todoDraft = "Retained draft";
        const glance = findChild(panel, "activityGlancePane");
        verify(glance !== null);
        compare(glance.children.length, 1);
        compare(glance.children[0].objectName, "activityScheduleSummary");
        compare(glance.children[0].y, 0, "calendar occupies the former weather position");
        verify(!panel.controller.notificationState.historyEnabled);
        compare(panel.controller.viewMemory.tabs, ["schedule"]);
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_1, Qt.ControlModifier);
        keyClick(Qt.Key_3, Qt.ControlModifier);
        compare(panel.unrelatedRequests, 0, "removed sections have no Activity shortcuts");
        keyClick(Qt.Key_2, Qt.ControlModifier);
        tryVerify(() => findChild(panel, "activityTodoDraft") !== null);
        compare(glance.children.length, 1, "expanded Activity keeps the schedule-only rail");
        compare(panel.controller.selectedDateKey, "2026-09-10");
        compare(findChild(panel, "activityTodoDraft").text, "Retained draft");
        compare(findChild(panel, "activityPreviousDay").Accessible.name, "Previous day");
        compare(findChild(panel, "activityNextDay").Accessible.name, "Next day");
        verify(!panel.detailsNavigation.headerButtons.some(button => button.accessKey === "T"), "Today is not duplicated in the expanded schedule");
        tryVerify(() => panel.detailsNavigation.headerButtons.some(button => button.surfaceShortcut === "Alt+O"));
        keyClick(Qt.Key_O, Qt.AltModifier);
        verify(!panel.controller.detailsOpen, "the custom header participates in shared letter shortcuts");
        panel.controller.closeSection();
        verify(!panel.controller.detailsOpen);
        compare(panel.controller.todoDraft, "Retained draft");
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
