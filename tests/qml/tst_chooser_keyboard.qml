pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
            property int headerTestWidth: 500
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
                            objectName: "testDetailsHeader"
                            uiScale: 1
                            width: Math.min(parent.width, surface.headerTestWidth)
                            title: "Inspector"
                            actions: [
                                {id: "first", label: "First", icon: "x", accessKey: "F", presentation: {group: "primary"}},
                                {id: "second", label: "Other", icon: "x", accessKey: "O", enabled: surface.headerEnabled, presentation: {group: "toolbar"}}
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
                        Ui.DetailSection {
                            objectName: "extraInformation"
                            informationOnly: true
                            title: "Extra information"
                            Ui.DetailFlickable {
                                objectName: "informationPage"
                                implicitHeight: 44
                                Ui.TextField {
                                    objectName: "informationValue"
                                    width: parent.width
                                    text: "Read-only information"
                                    readOnly: true
                                    activeFocusOnTab: false
                                }
                            }
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
                        Ui.DetailSection {
                            title: "Additional actions"
                            Ui.ActionButton {
                                objectName: "action"
                                Layout.fillWidth: true
                                label: "Apply"
                                onClicked: surface.actionCalls++
                            }
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
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        verify(controller.settingsInFlight);
        const update = calls.find(call => call.method === "applications.settings.update");
        verify(update !== undefined);
        compare(choice.value, "shell", "proposal does not acknowledge a setting");
        verify(content.detailsNavigation.browsing, "save leaves editing while acknowledgement is pending");
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
        keyClick(Qt.Key_Return);
        verify(navigation.editing);
        navigation.showEditor = false;
        verify(navigation.browsing);
        compare(navigation.currentTarget, navigation.contentItem);
        keyClick(Qt.Key_Down);
        compare(navigation.contentItem.contentY, 0, "Up/Down never traverse or scroll fields");
        keyClick(Qt.Key_PageDown);
        verify(navigation.contentItem.contentY >= navigation.height);
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
        verify(surface.listItem.listFocused, "Right expands without entering fields");
        keyClick(Qt.Key_Tab);
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

    function test_tabTraversalWrapsInsideDetailsAndSkipsInformationAndTabSelectors() {
        const surface = makeSurface();
        keyClick(Qt.Key_Tab);
        verify(surface.listItem.listFocused);
        compare(surface.chooserController.selectionModel.selectedIndex, 1);
        keyClick(Qt.Key_Tab);
        verify(surface.listItem.searchFocused);
        verify(!surface.chooserController.detailsOpen, "Tab does not implicitly open details");
        enterDetails(surface);
        compare(surface.detailsNavigation.targets.length, 4, "actions, information and tab selectors are not browsing stops");
        const information = findChild(surface, "informationValue");
        verify(information.visible);
        compare(Ui.FocusLocations.targets(surface.detailsItem).indexOf(information), -1, "information cannot be restored as an editor");
        compare(surface.detailsNavigation.currentTarget.objectName, "settingRow");
        for (const name of ["editor", "choice", "toggle", "settingRow"]) {
            keyClick(Qt.Key_Tab);
            verify(surface.detailsNavigation.browsing);
            compare(surface.detailsNavigation.currentTarget.objectName, name);
            verify(surface.detailsNavigation.highlightedControl.browseFocused, "browse uses the control's own focus paint");
            compare(surface.chooserController.selectionModel.selectedIndex, 1);
        }
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget.objectName, "toggle");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget.objectName, "choice");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget.objectName, "editor", "reverse traversal also skips information");
        compare(surface.settingEdits, 0);
        compare(surface.actionCalls, 0);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(surface.tabChanges, 1);
        verify(surface.detailsNavigation.browsing);
    }

    function test_headerShortcutsDoNotEnterTheContentCycleOrStealFocus_data() {
        return [{tag: "wide", width: 500}, {tag: "compact", width: 320}];
    }
    function test_headerShortcutsDoNotEnterTheContentCycleOrStealFocus(data) {
        const surface = makeSurface();
        surface.headerTestWidth = data.width;
        enterDetails(surface);
        tryCompare(surface.detailsNavigation.headerButtons, "length", 2);
        const first = surface.detailsNavigation.headerButtons[0];
        verify(!first.activeFocusOnTab);
        verify(first.Accessible.description.includes("Alt+F"));
        keyClick(Qt.Key_1, Qt.AltModifier);
        compare(surface.headerCalls, 0, "numeric header shortcuts are removed");
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(surface.headerCalls, 1);
        compare(surface.lastHeaderAction, "first");
        verify(surface.detailsNavigation.browsing);
        surface.headerEnabled = false;
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(surface.headerCalls, 1, "disabled actions keep their slot but cannot execute");
        surface.headerEnabled = true;
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(surface.lastHeaderAction, "second");
        compare(surface.headerCalls, 2);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        const choice = findChild(surface.detailsItem, "choice");
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(surface.headerCalls, 2, "a native menu blocks header actions");
        keyClick(Qt.Key_Escape);
        tryCompare(choice.popup, "visible", false);
        surface.modal = true;
        wait(0);
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(surface.headerCalls, 2, "a required-input modal owns its keys");
        surface.modal = false;
        wait(0);
        surface.listItem.focusList();
        surface.chooserController.closeDetails();
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(surface.headerCalls, 2, "closed details cannot dispatch shortcuts");
    }
    function test_modifierHintsRequireHoldAndFollowActualShortcutSlots_data() {
        return [{tag: "wide", width: 500}, {tag: "compact", width: 320}];
    }
    function test_modifierHintsRequireHoldAndFollowActualShortcutSlots(data) {
        const surface = makeSurface();
        surface.headerTestWidth = data.width;
        enterDetails(surface);
        surface.listItem.focusSearch();
        const hints = findChild(surface, "shortcutHints");
        const input = findChild(surface.listItem, "fieldInput");
        tryVerify(() => hints.listening);
        wait(0);
        tryCompare(surface.detailsNavigation.headerButtons, "length", 2);
        const first = surface.detailsNavigation.headerButtons[0];
        const second = surface.detailsNavigation.headerButtons[1];
        let firstBadge = findChild(first, "headerShortcutBadge");
        let secondBadge = findChild(second, "headerShortcutBadge");
        const tabBadge = findChild(surface.detailsItem, "tabShortcutBadge");
        verify(firstBadge !== null && secondBadge !== null && tabBadge !== null);
        verify(!firstBadge.visible && !tabBadge.visible);
        compare(input.Keys.forwardTo.length, 1);
        compare(input.Keys.forwardTo[0], hints);
        keyPress(Qt.Key_Alt);
        verify(hints.altDown, "Alt press is observed from the native editor");
        wait(100);
        verify(!firstBadge.visible);
        keyRelease(Qt.Key_Alt);
        wait(200);
        verify(!firstBadge.visible, "a tap cannot queue a later reveal");
        keyPress(Qt.Key_Alt);
        tryCompare(firstBadge, "visible", true);
        compare(firstBadge.text, "F");
        compare(secondBadge.text, "O");
        verify(input.activeFocus);
        surface.headerEnabled = false;
        wait(0);
        firstBadge = findChild(surface.detailsNavigation.headerButtons[0], "headerShortcutBadge");
        secondBadge = findChild(surface.detailsNavigation.headerButtons[1], "headerShortcutBadge");
        verify(secondBadge.visible, "disabled actions retain their letter");
        compare(secondBadge.text, "O");
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(surface.headerCalls, 0);
        keyRelease(Qt.Key_Alt);
        verify(!firstBadge.visible);
        surface.headerEnabled = true;
        wait(0);
        firstBadge = findChild(surface.detailsNavigation.headerButtons[0], "headerShortcutBadge");
        keyPress(Qt.Key_Alt);
        tryCompare(firstBadge, "visible", true);
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(surface.headerCalls, 1);
        verify(input.activeFocus);
        keyRelease(Qt.Key_Alt);
        verify(!firstBadge.visible);

        keyPress(Qt.Key_Control);
        tryCompare(tabBadge, "visible", true);
        compare(tabBadge.text, "Ctrl+Tab");
        keyPress(Qt.Key_Shift, Qt.ControlModifier);
        compare(tabBadge.text, "Ctrl+Shift+Tab");
        keyRelease(Qt.Key_Shift, Qt.ControlModifier);
        keyRelease(Qt.Key_Control);
        verify(!tabBadge.visible);
        keyClick(Qt.Key_X);
        verify(input.text.includes("x"), "observing modifiers must not consume native editing");

        keyPress(Qt.Key_Alt);
        tryCompare(firstBadge, "visible", true);
        const choice = findChild(surface.detailsItem, "choice");
        choice.forceActiveFocus();
        choice.popup.open();
        tryCompare(choice.popup, "visible", true);
        verify(!firstBadge.visible && !hints.altDown, "native menus clear modifier hints");
        keyRelease(Qt.Key_Alt);
        choice.popup.close();
        surface.listItem.focusSearch();
        keyPress(Qt.Key_Alt);
        wait(100);
        surface.chooserController.uiActive = false;
        wait(300);
        verify(!hints.altDown && !firstBadge.visible, "deactivation cancels the pending timer");
        keyRelease(Qt.Key_Alt);
        surface.chooserController.uiActive = true;
        surface.listItem.focusSearch();
        keyPress(Qt.Key_Alt);
        tryCompare(firstBadge, "visible", true);
        surface.modal = true;
        verify(!firstBadge.visible);
        keyRelease(Qt.Key_Alt);
        surface.modal = false;
        surface.listItem.focusSearch();
        keyPress(Qt.Key_Alt);
        keyPress(Qt.Key_Control, Qt.AltModifier);
        wait(300);
        verify(!firstBadge.visible && !tabBadge.visible, "Ctrl+Alt/AltGr is not an access-key request");
        keyRelease(Qt.Key_Control, Qt.AltModifier);
        keyRelease(Qt.Key_Alt);
        keyPress(Qt.Key_Alt);
        tryCompare(firstBadge, "visible", true);
        testCase.forceActiveFocus();
        verify(!firstBadge.visible && !hints.altDown);
        compare(input.Keys.forwardTo.length, 0, "focus loss restores key forwarding");
        keyRelease(Qt.Key_Alt);
        surface.listItem.focusSearch();
        wait(300);
        verify(!firstBadge.visible);
        surface.chooserController.closeDetails();
        keyPress(Qt.Key_Alt);
        wait(300);
        verify(!hints.showActions && !hints.showTabs);
        keyRelease(Qt.Key_Alt);
    }

    Component {
        id: keyReceiverFactory
        Item {
            property int keys: 0
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Z)
                    keys++;
                event.accepted = false;
            }
        }
    }
    function test_modifierObserverPreservesExistingForwarding() {
        const surface = makeSurface();
        const input = findChild(surface.listItem, "fieldInput");
        const receiver = createTemporaryObject(keyReceiverFactory, testCase);
        testCase.forceActiveFocus();
        input.Keys.forwardTo = [receiver];
        surface.listItem.focusSearch();
        compare(input.Keys.forwardTo.length, 2);
        compare(input.Keys.forwardTo[1], receiver);
        keyClick(Qt.Key_Z);
        compare(receiver.keys, 1);
        verify(input.text.includes("z"));
        testCase.forceActiveFocus();
        compare(input.Keys.forwardTo.length, 1);
        compare(input.Keys.forwardTo[0], receiver);
    }

    function test_tabSavesAndRetainsEditingWithoutReplayingActivation() {
        const surface = makeSurface();
        enterDetails(surface);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const editor = findChild(surface.detailsItem, "editor");
        verify(editor.inputActiveFocus);
        keyClick(Qt.Key_X);
        const text = editor.text;
        keyClick(Qt.Key_Tab);
        verify(surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget.objectName, "choice");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, editor);
        verify(editor.inputActiveFocus);
        compare(editor.text, text);
        compare(surface.settingEdits, 0);
        compare(surface.actionCalls, 0);
    }
    function test_browseEditAndEscapeNeverMutateWhileBrowsing() {
        const surface = makeSurface();
        enterDetails(surface);
        const row = findChild(surface.detailsItem, "settingRow");
        keyClick(Qt.Key_Down);
        compare(surface.chooserController.selectionModel.selectedIndex, 2);
        verify(surface.chooserController.detailsOpen);
        verify(surface.listItem.listFocused);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Tab);
        compare(surface.settingEdits, 0);
        compare(row.value, 50);
        keyClick(Qt.Key_Return);
        verify(row.inputActiveFocus);
        compare(surface.settingEdits, 0, "entering a slider does not edit it");
        keyClick(Qt.Key_Right);
        compare(row.value, 60);
        compare(surface.settingEdits, 0, "slider draft remains local until save");
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        verify(surface.chooserController.detailsOpen);
        compare(row.value, 50, "Escape discards the current field draft");
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
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const choice = findChild(surface.detailsItem, "choice");
        verify(choice.activeFocus);
        keyClick(Qt.Key_Space);
        tryCompare(choice.popup, "visible", true);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Escape);
        tryCompare(choice.popup, "visible", false);
        verify(surface.detailsNavigation.browsing, "Escape closes the menu and discards the edit");
        compare(choice.value, "a");
        compare(surface.settingEdits, 0);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Space);
        compare(surface.settingEdits, 0, "browsing a switch does not activate it");
        keyClick(Qt.Key_Return);
        compare(surface.settingEdits, 1, "Enter immediately toggles a browsed switch");
        verify(surface.detailsNavigation.browsing);
        findChild(surface.detailsItem, "toggle").interactive = false;
        keyClick(Qt.Key_Tab);
        verify(surface.detailsNavigation.currentTarget.objectName !== "action");
        compare(surface.actionCalls, 0, "actions never enter field traversal");
    }

    Component {
        id: tallModalFactory
        Ui.ModalFrame {
            anchors.fill: null
            width: 400
            height: 240
            title: "Confirm service action"
            detail: "Required instructions. ".repeat(60)
            Ui.TextField { objectName: "modalFirst"; width: parent.width; text: "draft"; sensitive: true }
            Item { width: parent.width; height: 450 }
            Ui.ActionButton { objectName: "modalLast"; width: parent.width; label: "Cancel" }
        }
    }
    function test_longModalScrollsFocusedInputsAndActionsIntoView() {
        const modal = createTemporaryObject(tallModalFactory, testCase);
        compare(modal.Accessible.role, Accessible.Dialog);
        compare(modal.Accessible.name, "Confirm service action");
        const first = findChild(modal, "modalFirst");
        const last = findChild(modal, "modalLast");
        const viewport = findChild(modal, "modalViewport");
        first.focusInput(false);
        tryVerify(() => viewport.contentHeight > viewport.height);
        keyClick(Qt.Key_Tab);
        tryVerify(() => last.activeFocus);
        tryVerify(() => last.mapToItem(viewport, 0, 0).y >= 0 && last.mapToItem(viewport, 0, last.height).y <= viewport.height + 1);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        tryVerify(() => first.inputActiveFocus);
        tryVerify(() => first.mapToItem(viewport, 0, 0).y >= 0 && first.mapToItem(viewport, 0, first.height).y <= viewport.height + 1);
        compare(first.text, "draft");
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
