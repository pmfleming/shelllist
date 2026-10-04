pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "FieldInteraction"
    when: windowShown
    visible: true
    width: 1000
    height: 650

    Component {
        id: factory
        Ui.ProviderChooserSurface {
            id: surface
            width: tests.width
            height: tests.height
            property int writes: 0
            property int actions: 0
            property string savedText: "original"
            property string savedChoice: "a"
            property real savedLevel: 40
            property bool switched: false
            property bool preview: false
            chooserController: Ui.ChooserController {
                id: controller
                uiActive: true
                hasSelection: true
                selectionModel: QtObject {
                    property int selectedIndex: 1
                    function move(delta) { selectedIndex = Math.max(0, Math.min(2, selectedIndex + delta)); }
                    function selectFirst() { selectedIndex = 0; }
                }
            }
            listComponent: Ui.ChooserListPane {
                chooserController: controller
                powerVisible: false
                resultModel: ["One", "Two", "Three"]
                rowDelegate: Rectangle { width: 300; height: 40 }
            }
            detailsComponent: Column {
                spacing: 10
                Ui.TextField {
                    objectName: "text"
                    width: parent.width
                    text: surface.savedText
                    onEdited: function (value) { surface.savedText = value; surface.writes++; }
                }
                Ui.DropDownList {
                    objectName: "choice"
                    width: parent.width
                    value: surface.savedChoice
                    options: [{value: "a", label: "A"}, {value: "b", label: "B"}, {value: "c", label: "C"}]
                    onSelected: function (value) { surface.savedChoice = value; surface.writes++; }
                }
                Ui.SegmentedControl {
                    objectName: "segments"
                    width: parent.width
                    value: surface.savedChoice
                    options: [{value: "a", label: "A"}, {value: "b", label: "B"}]
                    onSelected: function (value) { surface.savedChoice = value; surface.writes++; }
                }
                Ui.LabeledValueSlider {
                    objectName: "level"
                    width: parent.width
                    label: "Level"
                    from: 0; to: 100; stepSize: 10
                    value: surface.savedLevel
                    livePreview: surface.preview
                    onEdited: { surface.savedLevel = value; surface.writes++; }
                }
                Ui.ToggleRow {
                    objectName: "switch"
                    width: parent.width
                    title: "Enabled"
                    checked: surface.switched
                    onClicked: { surface.switched = !surface.switched; surface.writes++; }
                }
                Ui.TextEditor {
                    objectName: "multiline"
                    width: parent.width
                    height: 70
                    text: "first\nsecond"
                    onEdited: surface.writes++
                }
                Ui.TextField {
                    objectName: "readOnly"
                    width: parent.width
                    text: "Information only"
                    readOnly: true
                }
                Ui.ActionButton {
                    objectName: "otherAction"
                    width: parent.width
                    label: "Other command"
                    onClicked: surface.actions++
                }
                Ui.ActionButton {
                    objectName: "action"
                    width: parent.width
                    label: "Run"
                    accessKey: "R"
                    onClicked: surface.actions++
                }
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    function make() {
        const surface = createTemporaryObject(factory, tests);
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        verify(surface.listItem.listFocused);
        keyClick(Qt.Key_Tab);
        verify(surface.detailsNavigation.browsing);
        return surface;
    }
    function field(surface, name) { return findChild(surface.detailsItem, name); }
    function browse(surface, name) {
        for (let i = 0; i < 8 && surface.detailsNavigation.currentTarget !== field(surface, name); i++)
            keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, field(surface, name));
    }
    function test_textDiscardSaveAndTabTransaction() {
        const surface = make();
        const text = field(surface, "text");
        const subtle = findChild(text, "focusRing");
        compare(subtle.border.width, 0);
        keyClick(Qt.Key_Return);
        compare(subtle.border.width, 2);
        keyClick(Qt.Key_X);
        compare(surface.writes, 0);
        keyClick(Qt.Key_Escape);
        compare(text.text, "original");
        compare(surface.writes, 0);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Y);
        const draft = text.text;
        keyClick(Qt.Key_Tab);
        compare(surface.savedText, draft);
        compare(surface.writes, 1);
        compare(surface.detailsNavigation.currentTarget, field(surface, "choice"));
        verify(surface.detailsNavigation.editing);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(text.inputActiveFocus);
        keyClick(Qt.Key_Z);
        keyClick(Qt.Key_Return);
        compare(surface.savedText, text.text);
        compare(surface.writes, 2);
        verify(surface.detailsNavigation.browsing);
    }
    function test_arrowsSelectResultsButNeverFields() {
        const surface = make();
        const first = surface.detailsNavigation.currentTarget;
        keyClick(Qt.Key_Down);
        compare(surface.chooserController.selectionModel.selectedIndex, 2);
        verify(surface.chooserController.detailsOpen);
        verify(surface.listItem.listFocused);
        compare(surface.detailsNavigation.currentTarget, first);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        tryVerify(() => surface.listItem.searchFocused);
        keyClick(Qt.Key_Up);
        verify(surface.listItem.searchFocused);
        compare(surface.chooserController.selectionModel.selectedIndex, 0);
        keyClick(Qt.Key_Down);
        verify(surface.listItem.listFocused);
        keyClick(Qt.Key_Left);
        verify(!surface.chooserController.detailsOpen);
    }
    function test_choicesStayLocalAndTwoOptionsAreNotSwitches() {
        const surface = make();
        browse(surface, "segments");
        keyClick(Qt.Key_Return);
        compare(surface.savedChoice, "a");
        keyClick(Qt.Key_Right);
        compare(field(surface, "segments").displayedValue, "b");
        compare(surface.writes, 0);
        keyClick(Qt.Key_Escape);
        compare(field(surface, "segments").displayedValue, "a");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        compare(surface.savedChoice, "b");
        compare(surface.writes, 1);
        browse(surface, "choice");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        tryCompare(field(surface, "choice").popup, "visible", true);
        keyClick(Qt.Key_Down);
        compare(surface.savedChoice, "b");
        keyClick(Qt.Key_Tab);
        compare(surface.savedChoice, "c");
        compare(surface.writes, 2);
        verify(surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget, field(surface, "segments"));
    }
    function test_sliderCommitAndLiveRollback_data() {
        return [{tag: "deferred", preview: false}, {tag: "live", preview: true}];
    }
    function test_sliderCommitAndLiveRollback(data) {
        const surface = make();
        surface.preview = data.preview;
        browse(surface, "level");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(field(surface, "level").value, 50);
        compare(surface.savedLevel, data.preview ? 50 : 40);
        keyClick(Qt.Key_Escape);
        compare(surface.savedLevel, 40);
        compare(field(surface, "level").value, 40);
        compare(surface.writes, data.preview ? 2 : 0);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Tab);
        compare(surface.savedLevel, 50);
        compare(surface.writes, data.preview ? 3 : 1);
        compare(surface.detailsNavigation.currentTarget, field(surface, "switch"));
        verify(surface.detailsNavigation.browsing);
        verify(!surface.switched, "Tab never toggles a switch");
        keyClick(Qt.Key_Return);
        verify(surface.switched);
        verify(surface.detailsNavigation.browsing);
        verify(field(surface, "switch").focusSurface !== field(surface, "switch"), "Only the switch is highlighted, not labels");
    }
    function test_wrappingSkipsActionsAndPreservesEditing() {
        const surface = make();
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, field(surface, "multiline"));
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing);
        verify(field(surface, "multiline").activeFocus);
        keyClick(Qt.Key_X);
        verify(field(surface, "multiline").text.includes("x"));
        verify(field(surface, "multiline").editSession.active);
        compare(field(surface, "multiline").editSession.originalValue, "first\nsecond");
        compare(surface.detailsNavigation.editorTarget, field(surface, "multiline"));
        keyClick(Qt.Key_Tab);
        compare(surface.writes, 1);
        compare(surface.detailsNavigation.currentTarget, field(surface, "text"));
        verify(surface.detailsNavigation.editing);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, field(surface, "multiline"));
        verify(surface.detailsNavigation.editing);
        compare(surface.actions, 0);
    }
    function test_commandChordsAndMenuNeverBecomeFieldStops() {
        const surface = make();
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(surface.actions, 1);
        compare(surface.writes, 0);
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => surface.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(surface.actions, 1, "command menus block underlying shortcuts");
        keyClick(Qt.Key_Return);
        tryVerify(() => !surface.detailsNavigation.commandMenuOpen);
        compare(surface.actions, 2);
        compare(surface.writes, 0, "commands do not commit an unrelated field draft");
        keyClick(Qt.Key_Escape);
        compare(field(surface, "text").text, "original");
        for (let index = 0; index < 9; index++) {
            keyClick(Qt.Key_Tab);
            verify(surface.detailsNavigation.currentTarget !== field(surface, "readOnly"));
            verify(surface.detailsNavigation.currentTarget !== field(surface, "action"));
        }
    }
    function test_restoringSwitchNeverActivatesIt() {
        const surface = make();
        surface.detailsNavigation.focusSessionLocation({target: "switch", editing: true});
        tryVerify(() => surface.detailsNavigation.browsing);
        compare(surface.writes, 0);
        verify(!surface.switched);
    }
    function test_disabledAndRemovedFieldsCannotCaptureTraversal() {
        const surface = make();
        field(surface, "choice").enabled = false;
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, field(surface, "segments"));
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        field(surface, "segments").visible = false;
        verify(surface.detailsNavigation.browsing);
        compare(surface.writes, 0);
        compare(surface.savedChoice, "a");
    }
    function test_pointerEditingAlsoDefersAndFocusLossDiscards() {
        const surface = make();
        const input = findChild(field(surface, "text"), "fieldInput");
        mouseClick(input, 25, 15);
        verify(surface.detailsNavigation.editing);
        keyClick(Qt.Key_X);
        compare(surface.writes, 0);
        surface.listItem.focusList();
        compare(field(surface, "text").text, "original");
        compare(surface.writes, 0);
    }
}
