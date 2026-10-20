pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Shelllist.Ui as Ui

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
            property int dismissals: 0
            property int primaryActions: 0
            property int settingEdits: 0
            property int actionCalls: 0
            property int tabChanges: 0
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
                            compactSecondaryActions: true
                            onActionTriggered: surface.actionCalls++
                            width: Math.min(parent.width, 500)
                            title: "Inspector"
                            actions: [
                                {id: "first", label: "First", icon: "x", accessKey: "F", presentation: {group: "primary"}},
                                {id: "second", label: "Other", icon: "x", accessKey: "O", presentation: {group: "toolbar"}}
                            ]
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
