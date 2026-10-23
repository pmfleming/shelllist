pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtTest
import Shelllist.Ui as Ui
import Shelllist.Core as Core

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
            property string savedMultiline: "first\nsecond"
            property string savedChoice: "a"
            property string changeAvailabilityOnSave: ""
            property bool transientFieldVisible: false
            property real savedLevel: 40
            property bool switched: false
            property bool preview: false
            chooserController: Ui.ChooserController {
                id: controller
                uiActive: true
                hasSelection: true
                selectionModel: Core.SelectionModel {
                    selectedIndex: 1
                    count: 3
                }
            }
            listComponent: Ui.ChooserListPane {
                chooserController: controller
                powerVisible: false
                resultModel: ["One", "Two", "Three"]
                rowDelegate: Rectangle { implicitWidth: 300; implicitHeight: 40 }
            }
            detailsComponent: Column {
                spacing: 10
                Ui.FormField {
                    objectName: "textComposition"
                    width: parent.width
                    label: "Device name"
                    supportingText: "Visible to nearby devices"
                    Ui.TextField {
                        objectName: "text"
                        Layout.fillWidth: true
                        text: surface.savedText
                        onEdited: function (value) { surface.savedText = value; surface.writes++; }
                    }
                }
                Ui.DropDownList {
                    objectName: "choice"
                    width: parent.width
                    value: surface.savedChoice
                    options: [{value: "a", label: "A"}, {value: "b", label: "B"}, {value: "c", label: "C"}]
                    onSelected: function (value) { surface.savedChoice = value; surface.writes++; }
                }
                Loader {
                    active: surface.transientFieldVisible
                    width: parent.width
                    sourceComponent: Ui.TextField {
                        objectName: "transient"
                        text: "unbound original"
                        onEdited: { surface.writes++; surface.transientFieldVisible = false; }
                    }
                }
                Ui.SegmentedControl {
                    id: segments
                    objectName: "segments"
                    width: parent.width
                    value: surface.savedChoice
                    options: [{value: "a", label: "A"}, {value: "b", label: "B"}]
                    onSelected: function (value) {
                        surface.savedChoice = value;
                        surface.writes++;
                        if (surface.changeAvailabilityOnSave === "disable") segments.enabled = false;
                        if (surface.changeAvailabilityOnSave === "hide") segments.visible = false;
                    }
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
                    text: surface.savedMultiline
                    onEdited: function (value) { surface.savedMultiline = value; surface.writes++; }
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
        const marker = findChild(subtle, "browseFocusIndicator");
        compare(subtle.border.width, 0);
        verify(marker.visible, "browsing is distinguishable without outlining the field");
        keyClick(Qt.Key_Return);
        compare(subtle.border.width, 0);
        verify(findChild(subtle, "editingFocusLine").visible);
        verify(!marker.visible, "editing uses its own stronger tone and edge");
        keyClick(Qt.Key_X);
        compare(surface.writes, 0);
        keyClick(Qt.Key_Escape);
        verify(marker.visible, "Escape restores browse paint immediately");
        compare(text.text, "original");
        compare(surface.writes, 0);
        surface.savedText = "backend after discard";
        compare(text.text, surface.savedText, "discard restores the source binding");
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
        surface.savedText = "backend after save";
        compare(text.text, surface.savedText, "save also restores the source binding");
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
        surface.savedLevel = 60;
        compare(field(surface, "level").value, 60, "rollback preserves the source binding");
        surface.savedLevel = 40;
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Tab);
        compare(surface.savedLevel, 50);
        compare(surface.writes, data.preview ? 3 : 1);
        compare(surface.detailsNavigation.currentTarget, field(surface, "switch"));
        verify(surface.detailsNavigation.browsing);
        surface.detailsNavigation.focusSessionLocation({target: "switch", editing: true});
        verify(surface.detailsNavigation.browsing);
        verify(!surface.switched, "neither Tab nor restoration toggles a switch");
        keyClick(Qt.Key_Return);
        verify(surface.switched);
        verify(surface.detailsNavigation.browsing);
        verify(field(surface, "switch").focusSurface !== field(surface, "switch"), "Only the switch is highlighted, not labels");
    }
    function test_commandRemovalClosesMenuWithoutRetargetingEnter() {
        const surface = make();
        const target = surface.detailsNavigation.currentTarget;
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => surface.detailsNavigation.commandMenuOpen);
        field(surface, "otherAction").visible = false;
        tryVerify(() => !surface.detailsNavigation.commandMenuOpen);
        verify(surface.detailsNavigation.browsing);
        compare(surface.detailsNavigation.currentTarget, target);
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing, "Enter returns to the field, not a replacement command");
        keyClick(Qt.Key_Escape);
        compare(surface.actions, 0);
        compare(surface.writes, 0);
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
}
