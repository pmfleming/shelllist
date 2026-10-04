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
    function test_transactionsPreserveModelBindings_data() {
        // Cover both native string controls, numeric boundary keys and live
        // rollback without repeating the slider key × outcome cross-product.
        return [
            {tag: "text-discard", name: "text", save: false, key: Qt.Key_X, preview: false},
            {tag: "text-save", name: "text", save: true, key: Qt.Key_X, preview: false},
            {tag: "multiline-discard", name: "multiline", save: false, key: Qt.Key_X, preview: false},
            {tag: "multiline-save", name: "multiline", save: true, key: Qt.Key_X, preview: false},
            {tag: "slider-home-discard", name: "level", save: false, key: Qt.Key_Home, preview: false},
            {tag: "slider-end-save", name: "level", save: true, key: Qt.Key_End, preview: false},
            {tag: "live-slider-rollback", name: "level", save: false, key: Qt.Key_Right, preview: true}
        ];
    }
    function test_transactionsPreserveModelBindings(data) {
        const surface = make();
        surface.preview = data.preview;
        browse(surface, data.name);
        const control = field(surface, data.name);
        const property = data.name === "level" ? "value" : "text";
        const source = data.name === "level" ? "savedLevel" : data.name === "multiline" ? "savedMultiline" : "savedText";
        const original = control[property];
        keyClick(Qt.Key_Return);
        keyClick(data.key);
        const draft = control[property];
        verify(draft !== original);
        compare(surface.writes, data.preview ? 1 : 0);
        keyClick(data.save ? Qt.Key_Return : Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        compare(control[property], data.save ? draft : original);
        verify(!control.editSession.active, "save/discard must end the transaction");
        compare(surface.writes, data.preview ? 2 : data.save ? 1 : 0);
        // Acknowledgement, refresh or selecting another entity must still flow
        // through the original binding after both cancellation and save.
        for (let round = 0; round < 2; round++) {
            surface[source] = data.name === "level" ? 70 + round * 10 : "backend update " + round;
            compare(control[property], surface[source], "the model binding survives a transaction");
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Escape); // Even a no-op discard must retain the binding.
        }
        compare(surface.writes, data.preview ? 2 : data.save ? 1 : 0);
    }
    function test_unboundFieldsKeepSavedDraftAndDiscardLocally_data() {
        return [{tag: "text", name: "text"}, {tag: "multiline", name: "multiline"}, {tag: "slider", name: "level"}];
    }
    function test_unboundFieldsKeepSavedDraftAndDiscardLocally(data) {
        const surface = make();
        browse(surface, data.name);
        const control = field(surface, data.name);
        const property = data.name === "level" ? "value" : "text";
        // Deliberately remove the fixture's source binding before edit entry.
        control[property] = data.name === "level" ? 20 : "unbound original";
        keyClick(Qt.Key_Return);
        keyClick(data.name === "level" ? Qt.Key_Right : Qt.Key_X);
        const draft = control[property];
        keyClick(Qt.Key_Return);
        compare(control[property], draft, "unbound inputs keep the committed draft");
        keyClick(Qt.Key_Return);
        keyClick(data.name === "level" ? Qt.Key_Right : Qt.Key_Y);
        verify(control[property] !== draft);
        keyClick(Qt.Key_Escape);
        compare(control[property], draft, "unbound inputs roll back to their edit-entry value");
        compare(surface.writes, 1);
    }
    function test_externalUpdateDoesNotOverwriteDraftAndBlurRestoresBinding() {
        const surface = make();
        const control = field(surface, "text");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        const draft = control.text;
        surface.savedText = "updated by backend while editing";
        compare(control.text, draft, "the local edit is isolated from incoming snapshots");
        surface.listItem.focusList();
        compare(control.text, surface.savedText, "discard reveals the latest authoritative value");
        surface.savedText = "another update";
        compare(control.text, surface.savedText);
        compare(surface.writes, 0);
    }
    function test_tabKeepsPositionWhenSaveChangesAvailability_data() {
        return [
            {tag: "disable-forward", change: "disable", backwards: false, skip: false},
            {tag: "disable-reverse", change: "disable", backwards: true, skip: false},
            {tag: "hide-forward-skip", change: "hide", backwards: false, skip: true},
            {tag: "hide-reverse-skip", change: "hide", backwards: true, skip: true}
        ];
    }
    function test_tabKeepsPositionWhenSaveChangesAvailability(data) {
        const surface = make();
        surface.changeAvailabilityOnSave = data.change;
        browse(surface, "segments");
        if (data.skip)
            field(surface, data.backwards ? "choice" : "level").enabled = false;
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Tab, data.backwards ? Qt.ShiftModifier : Qt.NoModifier);
        compare(surface.savedChoice, "b");
        compare(surface.writes, 1, "only the field being saved may dispatch a change");
        const expected = data.backwards ? (data.skip ? "text" : "choice") : (data.skip ? "switch" : "level");
        compare(surface.detailsNavigation.currentTarget, field(surface, expected));
        if (expected === "switch") {
            verify(surface.detailsNavigation.browsing);
            verify(!surface.switched);
        } else {
            verify(surface.detailsNavigation.editing, "Tab retains edit mode on the correct neighbour");
        }
    }
    function test_tabKeepsPositionWhenSaveRemovesField_data() {
        return [{tag: "forward", backwards: false}, {tag: "reverse", backwards: true}];
    }
    function test_tabKeepsPositionWhenSaveRemovesField(data) {
        const surface = make();
        surface.transientFieldVisible = true;
        tryVerify(() => field(surface, "transient") !== null);
        tryVerify(() => surface.detailsNavigation.targets.includes(field(surface, "transient")));
        browse(surface, "transient");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Tab, data.backwards ? Qt.ShiftModifier : Qt.NoModifier);
        compare(surface.writes, 1);
        verify(!surface.transientFieldVisible);
        compare(surface.detailsNavigation.currentTarget, field(surface, data.backwards ? "choice" : "segments"));
        verify(surface.detailsNavigation.editing);
        wait(0); // Complete Loader teardown without invalidating the new editor.
        compare(field(surface, "transient"), null);
        verify(surface.detailsNavigation.editing);
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
        keyClick(Qt.Key_Return, Qt.ShiftModifier);
        compare(field(surface, "multiline").text.split("\n").length, 3, "Shift+Enter stays a native newline");
        compare(surface.writes, 0);
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
    function test_contentMenuWrapsSkipsDisabledAndTracksAvailability() {
        const surface = make();
        const action = field(surface, "action");
        const other = field(surface, "otherAction");
        action.accessKey = "";
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => surface.detailsNavigation.commandMenuOpen);
        const menu = findChild(surface, "detailsCommandMenu");
        compare(menu.currentIndex, 0);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(menu.currentIndex, 1);
        other.enabled = false;
        compare(menu.currentIndex, 1, "availability changes must not select a different command");
        keyClick(Qt.Key_Down);
        compare(menu.currentIndex, 1, "disabled commands are skipped on wrap");
        keyClick(Qt.Key_Return);
        compare(surface.actions, 1);
        verify(surface.detailsNavigation.browsing);
        compare(surface.writes, 0);
    }
    function test_restoringSwitchNeverActivatesIt() {
        const surface = make();
        surface.detailsNavigation.focusSessionLocation({target: "switch", editing: true});
        tryVerify(() => surface.detailsNavigation.browsing);
        compare(surface.writes, 0);
        verify(!surface.switched);
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
