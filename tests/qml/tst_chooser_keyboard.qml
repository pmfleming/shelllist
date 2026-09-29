pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import "../../launcher" as Apps

DaemonTestCase {
    id: testCase
    name: "ChooserKeyboard"
    when: windowShown
    visible: true
    width: 1100
    height: 700

    Component {
        id: surfaceComponent
        Ui.ProviderChooserSurface {
            id: surface
            width: testCase.width
            height: testCase.height
            keyboardWorkflow: true
            property int dismissals: 0
            property int primaryActions: 0
            property int settingEdits: 0
            property int actionCalls: 0
            property int tabChanges: 0
            property int headerCalls: 0
            property bool headerEnabled: true
            property string lastHeaderAction: ""
            property bool modal: false
            navigationEnabled: !modal
            chooserController: Ui.ChooserController {
                id: controller
                uiActive: true
                hasSelection: true
                detailActions: [{id: "legacy-action", shortcut: "J", enabled: true}]
                function triggerDetailAction(actionId) { surface.actionCalls++; return true; }
                selectionModel: QtObject {
                    property string queryText: "abcd"
                    property int selectedIndex: 1
                    function selectFirst() { selectedIndex = 0; }
                    function move(delta) { selectedIndex = Math.max(0, Math.min(2, selectedIndex + delta)); }
                }
                function primarySelected() { surface.primaryActions++; return true; }
                function cycleDetailsTab() { surface.tabChanges++; }
                onCloseWindowRequested: surface.dismissals++
            }
            listComponent: Component {
                Ui.ChooserListPane {
                    chooserController: controller
                    filterText: controller.selectionModel.queryText
                    resultModel: ["First", "Second", "Third"]
                    powerVisible: false
                    rowDelegate: Component {
                        Rectangle { width: 400; height: 48 }
                    }
                }
            }
            detailsComponent: Component {
                Item {
                    Column {
                        width: parent.width
                        spacing: 12
                        Ui.DetailsHeader {
                            uiScale: 1
                            width: parent.width
                            title: "Inspector"
                            actions: [
                                {id: "first", label: "First", icon: "x", presentation: {group: "primary"}},
                                {id: "second", label: "Second", icon: "x", enabled: surface.headerEnabled, presentation: {group: "toolbar"}}
                            ]
                            onActionTriggered: function (id) { surface.headerCalls++; surface.lastHeaderAction = id; }
                        }
                        Ui.LabeledValueSlider {
                            objectName: "settingRow"
                            width: parent.width
                            height: 44
                            label: "Volume"
                            value: 50
                            from: 0
                            to: 100
                            stepSize: 10
                            onEdited: surface.settingEdits++
                        }
                        Ui.TextField {
                            objectName: "editor"
                            width: parent.width
                            text: "name"
                        }
                        Ui.DropDownList {
                            objectName: "choice"
                            width: parent.width
                            options: [{value: "a", label: "First"}, {value: "b", label: "Second"}]
                            value: "a"
                            onSelected: surface.settingEdits++
                        }
                        Ui.ToggleRow {
                            objectName: "toggle"
                            width: parent.width
                            title: "Enabled"
                            onClicked: surface.settingEdits++
                        }
                        Ui.ActionButton {
                            objectName: "action"
                            width: parent.width
                            label: "Apply"
                            onClicked: surface.actionCalls++
                        }
                        Ui.DetailsTabBar {
                            width: parent.width
                            tabs: [{value: "one", label: "One"}, {value: "two", label: "Two"}]
                            selectedValue: "one"
                        }
                    }
                }
            }
            Ui.PromptDialog {
                objectName: "prompt"
                visible: surface.modal
                title: "Password"
                password: true
                actionsVisible: true
                onCancelled: surface.modal = false
            }
        }
    }

    Component {
        id: applicationsComponent
        Apps.ApplicationContent {
            width: testCase.width
            height: testCase.height
            controller: Apps.ApplicationController {}
        }
    }
    function test_applicationsSettingsKeepAcknowledgementAndRegionFocus() {
        const content = createTemporaryObject(applicationsComponent, testCase);
        const controller = content.controller;
        wait(0);
        controller.uiActive = true;
        controller.replaceProviderResults([controller.provider.resultFor({
            id: "example.desktop", name: "Example", kind: "desktop-application",
            category: "shell", default_workspace_id: "1", instances: [], desktop_actions: [],
            running: false, focused: false
        })], true);
        tryVerify(() => controller.hasSelection);
        enterDetails(content);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(controller.detailsTab, "resources");
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(controller.detailsTab, "settings");
        keyClick(Qt.Key_Tab, Qt.ControlModifier | Qt.ShiftModifier);
        compare(controller.detailsTab, "resources");
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(controller.detailsTab, "settings");
        tryVerify(() => content.detailsNavigation.currentTarget && content.detailsNavigation.currentTarget instanceof Ui.DropDownList);
        verify(content.detailsNavigation.browsing);
        const choice = content.detailsNavigation.currentTarget;
        compare(choice.value, "shell");
        calls = [];
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        verify(controller.settingsInFlight);
        const update = calls.find(call => call.method === "applications.settings.update");
        verify(update !== undefined);
        compare(choice.value, "shell", "proposal does not acknowledge a setting");
        verify(content.detailsNavigation.editing, "pending acknowledgement retains editor ownership");
        keyClick(Qt.Key_Escape);
        verify(content.detailsNavigation.browsing);
        keyClick(Qt.Key_Tab);
        verify(content.detailsNavigation.browsing);
        verify(!choice.enabled, "pending settings cannot be entered again");
        compare(content.detailsNavigation.currentTarget.objectName, "applicationSettingsPage", "Tab stays in Settings with a scrollable fallback while its control is disabled");
        content.destroy();
        wait(0);
    }

    Component {
        id: readOnlyPageComponent
        Ui.DetailsNavigation {
            id: navigation
            width: 400
            height: 240
            property bool showEditor: true
            contentItem: page
            Ui.DetailFlickable {
                id: page
                anchors.fill: parent
                Ui.TextField {
                    objectName: "removableEditor"
                    visible: navigation.showEditor
                    width: parent.width
                    text: "ordinary draft"
                }
                Ui.ThemeText {
                    width: parent.width
                    height: 900
                    text: "Read-only details"
                }
            }
        }
    }
    function test_removedEditorFallsBackToScrollableContent() {
        const navigation = createTemporaryObject(readOnlyPageComponent, testCase);
        tryVerify(() => navigation.contentItem.contentHeight > navigation.height);
        navigation.focusContent(true);
        keyClick(Qt.Key_Right);
        verify(navigation.editing);
        navigation.showEditor = false;
        verify(navigation.browsing);
        compare(navigation.currentTarget, navigation.contentItem);
        keyClick(Qt.Key_Down);
        verify(navigation.contentItem.contentY > 0);
        keyClick(Qt.Key_PageDown);
        verify(navigation.contentItem.contentY > navigation.height);
        navigation.showEditor = true;
        compare(navigation.currentTarget, navigation.contentItem, "new content does not steal the browse cursor");
        verify(navigation.browsing);
    }

    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
        verify(!Ui.Theme.noAnimations);
    }
    function cleanup() {
        Quickshell.environment = ({});
    }
    function makeSurface() {
        const surface = createTemporaryObject(surfaceComponent, testCase);
        verify(surface !== null);
        surface.listItem.focusSearch();
        wait(0);
        return surface;
    }
    function enterDetails(surface) {
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        tryVerify(() => surface.detailsNavigation.currentTarget !== null);
        verify(surface.detailsNavigation.browsing);
    }

    function test_searchOwnsPrintableKeysAndSavedCursor() {
        const surface = makeSurface();
        const input = findChild(surface.listItem, "fieldInput");
        input.cursorPosition = 2;
        keyClick(Qt.Key_Left);
        compare(input.cursorPosition, 1);
        keyClick(Qt.Key_Down);
        verify(surface.listItem.listFocused);
        compare(surface.chooserController.selectionModel.selectedIndex, 0);
        keyClick(Qt.Key_Down);
        compare(surface.chooserController.selectionModel.selectedIndex, 1);
        surface.chooserController.detailsOpen = true;
        keyClick(Qt.Key_J);
        compare(surface.actionCalls, 0, "letters cannot trigger legacy detail mnemonics");
        verify(surface.listItem.searchFocused);
        compare(input.text, "ajbcd");
        compare(input.cursorPosition, 2);
        compare(surface.chooserController.selectionModel.queryText, "ajbcd");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_K);
        compare(input.text, "ajkbcd");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        verify(surface.listItem.searchFocused);
        keyClick(Qt.Key_Return);
        compare(surface.primaryActions, 1);
    }

    function test_tabTraversalWrapsInsideDetailsAndSkipsTabSelectors() {
        const surface = makeSurface();
        keyClick(Qt.Key_Tab);
        verify(surface.listItem.listFocused);
        compare(surface.chooserController.selectionModel.selectedIndex, 1);
        keyClick(Qt.Key_Tab);
        verify(surface.listItem.searchFocused);
        verify(!surface.chooserController.detailsOpen, "Tab does not implicitly open details");
        enterDetails(surface);
        compare(surface.detailsNavigation.targets.length, 5, "tab selector is not content");
        compare(surface.detailsNavigation.currentTarget.objectName, "settingRow");
        for (const name of ["editor", "choice", "toggle", "action", "settingRow"]) {
            keyClick(Qt.Key_Tab);
            verify(surface.detailsNavigation.browsing);
            compare(surface.detailsNavigation.currentTarget.objectName, name);
            verify(surface.detailsNavigation.highlightedControl.browseFocused, "browse uses the control's own focus paint");
            compare(surface.chooserController.selectionModel.selectedIndex, 1);
        }
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget.objectName, "action");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget.objectName, "toggle");
        compare(surface.settingEdits, 0);
        compare(surface.actionCalls, 0);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(surface.tabChanges, 1);
        verify(surface.detailsNavigation.browsing);
    }

    function test_headerShortcutsDoNotEnterTheContentCycleOrStealFocus() {
        const surface = makeSurface();
        enterDetails(surface);
        tryCompare(surface.detailsNavigation.headerButtons, "length", 2);
        const first = surface.detailsNavigation.headerButtons[0];
        verify(!first.activeFocusOnTab);
        verify(first.Accessible.description.includes("Alt+1"));
        keyClick(Qt.Key_1, Qt.AltModifier);
        compare(surface.headerCalls, 1);
        compare(surface.lastHeaderAction, "first");
        verify(surface.detailsNavigation.browsing);
        surface.headerEnabled = false;
        keyClick(Qt.Key_2, Qt.AltModifier);
        compare(surface.headerCalls, 1, "disabled actions keep their slot but cannot execute");
        surface.headerEnabled = true;
        keyClick(Qt.Key_2, Qt.AltModifier);
        compare(surface.lastHeaderAction, "second");
        compare(surface.headerCalls, 2);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        const choice = findChild(surface.detailsItem, "choice");
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_1, Qt.AltModifier);
        compare(surface.headerCalls, 2, "a native menu blocks header actions");
        keyClick(Qt.Key_Escape);
        tryCompare(choice.popup, "visible", false);
        surface.modal = true;
        wait(0);
        keyClick(Qt.Key_1, Qt.AltModifier);
        compare(surface.headerCalls, 2, "a required-input modal owns its keys");
        surface.modal = false;
        wait(0);
        surface.listItem.focusList();
        surface.chooserController.closeDetails();
        keyClick(Qt.Key_1, Qt.AltModifier);
        compare(surface.headerCalls, 2, "closed details cannot dispatch shortcuts");
    }
    function test_tabLeavesEditorWithoutReplayingActivation() {
        const surface = makeSurface();
        enterDetails(surface);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const editor = findChild(surface.detailsItem, "editor");
        verify(editor.inputActiveFocus);
        keyClick(Qt.Key_X);
        const text = editor.text;
        keyClick(Qt.Key_Tab);
        verify(surface.detailsNavigation.browsing);
        compare(surface.detailsNavigation.currentTarget.objectName, "choice");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, editor);
        verify(!editor.inputActiveFocus);
        compare(editor.text, text);
        compare(surface.settingEdits, 0);
        compare(surface.actionCalls, 0);
    }
    function test_browseEditAndEscapeNeverMutateWhileBrowsing() {
        const surface = makeSurface();
        enterDetails(surface);
        const row = findChild(surface.detailsItem, "settingRow");
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        compare(surface.settingEdits, 0);
        compare(row.value, 50);
        keyClick(Qt.Key_Return);
        verify(row.inputActiveFocus);
        compare(surface.settingEdits, 0, "entering a slider does not edit it");
        keyClick(Qt.Key_Right);
        compare(row.value, 60);
        compare(surface.settingEdits, 1);
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        verify(surface.chooserController.detailsOpen);
        compare(row.value, 60, "leaving an editor does not undo applied settings");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const editor = findChild(surface.detailsItem, "editor");
        verify(editor.inputActiveFocus);
        keyClick(Qt.Key_Left);
        verify(editor.inputActiveFocus, "Left edits text, not surface navigation");
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Left);
        verify(surface.listItem.listFocused);
        verify(!surface.chooserController.detailsOpen);
        compare(surface.dismissals, 0);
        keyClick(Qt.Key_Escape);
        compare(surface.dismissals, 1);
    }

    function test_popupEscapeAndGuardedToggleActivation() {
        const surface = makeSurface();
        enterDetails(surface);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Right);
        const choice = findChild(surface.detailsItem, "choice");
        verify(choice.activeFocus);
        keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        tryCompare(choice.popup, "visible", false);
        verify(!surface.detailsNavigation.browsing, "first Escape closes only the native menu");
        compare(choice.value, "a");
        compare(surface.settingEdits, 0);
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Space);
        compare(surface.settingEdits, 0, "browsing a switch does not activate it");
        keyClick(Qt.Key_Return);
        compare(surface.settingEdits, 0, "Enter focuses a browsed switch without toggling it");
        keyClick(Qt.Key_Space);
        compare(surface.settingEdits, 1);
        keyClick(Qt.Key_Escape);
        findChild(surface.detailsItem, "toggle").interactive = false;
        keyClick(Qt.Key_Right);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(surface.actionCalls, 1);
    }

    function test_modalUsesConventionalTabAndOwnEscape() {
        const surface = makeSurface();
        enterDetails(surface);
        surface.modal = true;
        const prompt = findChild(surface, "prompt");
        tryVerify(() => prompt.visible);
        wait(0);
        const input = findChild(prompt, "fieldInput");
        verify(input.activeFocus);
        for (let index = 0; index < 10; ++index) {
            keyClick(Qt.Key_Tab, index < 5 ? Qt.NoModifier : Qt.ShiftModifier);
            verify(prompt.containsItem(prompt.Window.window.activeFocusItem), "Tab stays in the modal");
        }
        keyClick(Qt.Key_Escape);
        verify(!surface.modal);
        verify(surface.detailsNavigation.browsing, "cancel restores preceding content focus");
        verify(surface.chooserController.detailsOpen);
        compare(surface.dismissals, 0);
    }
}
