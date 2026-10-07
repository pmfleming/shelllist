pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtTest
import Shelllist.Ui as Ui
import "ColorContrast.js" as Contrast

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
            property int copies: 0
            property string savedName: "Studio headphones"
            property string savedNote: "One line"
            property alias nameForm: nameForm
            property alias nameField: nameField
            property alias observedForm: observedForm
            property alias observed: observed
            property alias note: note
            Rectangle { anchors.fill: parent; color: Ui.Theme.surface }
            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 10
                Ui.FormField {
                    id: nameForm
                    width: parent.width
                    label: "Name"
                    accessibleName: "Device name"
                    supportingText: "Visible to nearby devices"
                    Ui.TextField {
                        id: nameField
                        objectName: "compactName"
                        Layout.fillWidth: true
                        text: surface.savedName
                        onEdited: function (value) { surface.savedName = value; surface.writes++; }
                    }
                }
                Ui.FormField {
                    id: observedForm
                    width: parent.width
                    label: "IPv4"
                    icon: "lan"
                    accessibleName: "IPv4 address"
                    readOnlyReason: "Assigned automatically"
                    copyAvailable: true
                    onCopyRequested: surface.copies++
                    Ui.TextField {
                        id: observed
                        objectName: "compactObserved"
                        Layout.fillWidth: true
                        text: "192.168.178.119"
                        readOnly: true
                    }
                }
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
    function cleanup(): void { Ui.Theme.previewColorScheme = Qt.Unknown; }
    function make(): var {
        const surface = createTemporaryObject(factory, tests);
        verify(surface !== null);
        surface.detailsNavigation.focusContent(true);
        verify(waitForPolish(surface.Window.window));
        return surface;
    }
    function test_inlineCompositionAndExplicitHelp(): void {
        const surface = make();
        const form = surface.nameForm;
        const input = findChild(surface.nameField, "fieldInput");
        const label = findChild(form, "formFieldLabel");
        const support = findChild(form, "formFieldSupport");
        compare(form.height, Ui.Theme.formHeight + 1);
        verify(label.mapToItem(form, 0, label.height / 2).y < Ui.Theme.formHeight);
        compare(input.Accessible.name, "Device name");
        verify(input.Accessible.description.includes(form.supportingText));
        verify(!support.visible);
        compare(surface.nameField.color.a, 0);
        verify(!findChild(surface.nameField, "fieldBaseline").visible, "one passive row separator, no doubled input baseline");
        verify(findChild(surface.nameField, "browseFocusIndicator").visible);
        mouseClick(label, label.width / 2, label.height / 2);
        verify(!surface.detailsNavigation.editing, "passive names do not start an editor");
        keyClick(Qt.Key_H, Qt.AltModifier);
        verify(form.helpOpen);
        verify(support.visible);
        verify(waitForPolish(surface.Window.window));
        verify(form.height > Ui.Theme.formHeight + 1);
        compare(surface.writes, 0);
        keyClick(Qt.Key_H, Qt.AltModifier);
        verify(!support.visible);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        compare(surface.writes, 0);
        keyClick(Qt.Key_H, Qt.AltModifier);
        verify(form.helpOpen);
        verify(surface.nameField.editSession.active, "disclosing help must not disturb a local draft");
        compare(surface.writes, 0);
        keyClick(Qt.Key_H, Qt.AltModifier);
        keyClick(Qt.Key_Tab);
        compare(surface.writes, 1);
        compare(surface.detailsNavigation.currentTarget, surface.note, "help, copy and read-only rows are not field stops");
        verify(surface.detailsNavigation.editing);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(surface.detailsNavigation.currentTarget, surface.nameField);
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
    }
    function test_readOnlyCommandsAreReachableWithoutFieldFocus(): void {
        const surface = make();
        const observed = surface.observed;
        const badge = findChild(observed, "fieldStateBadge");
        verify(badge.visible);
        compare(findChild(badge, "fieldStateGlyph").symbol, "lock");
        verify(!badge.activeFocusOnTab);
        compare(observed.opacity, 1);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => surface.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_Return);
        tryVerify(() => !surface.detailsNavigation.commandMenuOpen);
        compare(surface.copies, 1, "first unscoped named command copies the read-only address");
        compare(surface.writes, 0);
        const help = findChild(surface.observedForm, "formFieldHelp");
        mouseClick(help, help.width / 2, help.height / 2);
        verify(surface.observedForm.helpOpen);
        compare(surface.observedForm.message, "Assigned automatically");
        mouseClick(badge, badge.width / 2, badge.height / 2);
        verify(!observed.editSession.active, "a lock never unlocks or starts editing");
        observed.enabled = false;
        compare(findChild(badge, "fieldStateGlyph").symbol, "block");
        compare(observed.opacity, 1);
        verify(findChild(observed, "fieldInput").Accessible.description.includes("Unavailable"));
        observed.enabled = true;
        observed.text = "";
        observed.placeholder = "192.168.1.20";
        compare(findChild(observed, "fieldPlaceholder").text, "—", "an empty automatic value must never look like a sample IP");
        verify(findChild(observed, "fieldInput").Accessible.description.includes("Not set"));
    }
    function test_multilineGrowsAndTransactionsSurviveResize(): void {
        const surface = make();
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
    function test_errorAndLongLabelGrowWithoutLosingEditor(): void {
        const surface = make();
        const form = surface.nameForm;
        const input = findChild(surface.nameField, "fieldInput");
        surface.width = 340;
        form.label = "A long translated device name";
        form.accessibleName = form.label;
        form.errorText = "This name cannot be saved. Choose a different name and retry the request.";
        verify(waitForPolish(surface.Window.window));
        verify(findChild(form, "formFieldSupport").visible);
        const label = findChild(form, "formFieldLabel");
        verify(form.height >= label.height);
        verify(input.width - input.leftPadding - input.rightPadding >= 80, "the value keeps a useful editing area at narrow widths");
        compare(input.Accessible.name, form.label);
        verify(input.Accessible.description.includes(form.errorText));
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Escape);
        compare(surface.nameField.text, surface.savedName);
        compare(surface.writes, 0);
        verify(form.errorText.length > 0, "discarding an unrelated draft never hides a domain failure");
    }
    function test_readOnlyContrast_data(): var {
        return [{tag: "light", scheme: Qt.Light}, {tag: "dark", scheme: Qt.Dark}];
    }
    function test_readOnlyContrast(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const surface = make();
        const input = findChild(surface.observed, "fieldInput");
        const badge = findChild(surface.observed, "fieldStateBadge");
        verify(Contrast.ratio(input.color, Ui.Theme.surface) >= 4.5);
        verify(Contrast.ratio(findChild(badge, "fieldStateGlyph").color, badge.color) >= 3);
        const before = surface.observed.text;
        surface.observed.focusInput(false);
        keyClick(Qt.Key_X);
        compare(surface.observed.text, before);
        verify(!findChild(surface.observed, "focusRing").visible);
    }
}
