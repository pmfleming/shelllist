pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "IpControl"
    when: windowShown
    visible: true
    width: 780
    height: 640

    Component {
        id: factory
        Ui.PanelSurface {
            id: panel
            anchors.fill: undefined
            width: tests.width
            height: tests.height
            chooserController: Ui.ChooserController { uiActive: true }
            property int writes: 0
            property var sources: ["", "", "", "", ""]
            property bool blocked: false
            property bool locked: false
            function save(index: int, value: string): void {
                const next = sources.slice();
                next[index] = value;
                sources = next;
                writes++;
            }
            navigationContent: content
            Column {
                id: content
                width: parent.width
                Repeater {
                    model: [
                        {family: "ipv4", mode: "address", notation: "prefix"},
                        {family: "ipv4", mode: "addressWithSubnet", notation: "prefix"},
                        {family: "ipv4", mode: "addressWithSubnet", notation: "netmask"},
                        {family: "ipv6", mode: "address", notation: "prefix"},
                        {family: "ipv6", mode: "addressWithSubnet", notation: "prefix"}
                    ]
                    delegate: Ui.FormField {
                        id: row
                        required property int index
                        required property var modelData
                        width: content.width
                        label: "IP"
                        accessibleName: modelData.family + " " + modelData.mode
                        Ui.IpField {
                            Layout.fillWidth: true
                            objectName: "ip" + row.index
                            family: row.modelData.family
                            mode: row.modelData.mode
                            subnetNotation: row.modelData.notation
                            allowEmpty: mode === "address"
                            text: panel.sources[row.index]
                            enabled: !panel.blocked
                            readOnly: panel.locked
                            onEdited: function (value) { panel.save(row.index, value); }
                        }
                    }
                }
            }
        }
    }
    TextEdit { id: clipboardSource; visible: false }
    function init() { failOnWarning(/.*/); }
    function make(index) {
        const panel = createTemporaryObject(factory, tests);
        panel.detailsNavigation.focusContent(true);
        for (let i = 0; i < index; i++) keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.currentTarget.objectName, "ip" + index);
        return panel;
    }
    function field(panel, index) { return findChild(panel, "ip" + index); }
    function input(panel, index) { return findChild(field(panel, index), "ipFieldInput"); }
    function type(value) {
        for (const ch of value) keyClick(ch.toUpperCase().charCodeAt(0), /[A-F]/.test(ch) ? Qt.ShiftModifier : Qt.NoModifier);
    }
    function clipboard(value) {
        clipboardSource.text = value;
        clipboardSource.selectAll();
        clipboardSource.copy();
    }
    function paste(value, selectAll = true) {
        clipboard(value);
        if (selectAll) keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_V, Qt.ControlModifier);
    }
    function test_modes_data() {
        return [
            {tag: "ipv4-address", index: 0, value: "192.168.001.20", saved: "192.168.1.20"},
            {tag: "ipv4-prefix", index: 1, value: "192.168.1.20/24", saved: "192.168.1.20/24"},
            {tag: "ipv4-mask", index: 2, value: "192.168.1.20 / 255.255.254.0", saved: "192.168.1.20/255.255.254.0"},
            {tag: "ipv6-address", index: 3, value: "2001:DB8::1", saved: "2001:db8::1"},
            {tag: "ipv6-prefix", index: 4, value: "::ffff:192.0.2.1/128", saved: "::ffff:192.0.2.1/128"}
        ];
    }
    function test_modes(data) {
        const panel = make(data.index);
        const editor = field(panel, data.index);
        compare(panel.detailsNavigation.availableFields().length, 5);
        verify(editor.browseFocused);
        keyClick(Qt.Key_Return);
        verify(editor.inputActiveFocus);
        paste(data.value);
        compare(panel.writes, 0);
        compare(editor.validationState, 2);
        keyClick(Qt.Key_Return);
        compare(panel.sources[data.index], data.saved);
        compare(panel.writes, 1);
        verify(panel.detailsNavigation.browsing);
        verify(editor.browseFocused);
        verify(!findChild(editor, "ipFieldCursor").visible);
        verify(input(panel, data.index).Accessible.description.includes("field") || data.index === 0 || data.index === 3);
        panel.save(data.index, "");
        compare(editor.text, "", "save restores its source binding");
    }
    function test_ipv4AutoAdvanceShortOctetsAndUndo() {
        const panel = make(1);
        const editor = field(panel, 1);
        keyClick(Qt.Key_Return);
        type("19216817811924");
        compare(editor.text, "192.168.178.119/24");
        compare(panel.writes, 0);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(editor.text, "192.168.178.119/2");
        keyClick(Qt.Key_Y, Qt.ControlModifier);
        compare(editor.text, "192.168.178.119/24");
        keyClick(Qt.Key_Escape);
        compare(editor.text, "");
        keyClick(Qt.Key_Return);
        type("10"); keyClick(Qt.Key_Right);
        type("0"); keyClick(Qt.Key_Right);
        type("0"); keyClick(Qt.Key_Right);
        type("1"); keyClick(Qt.Key_Right);
        type("24");
        compare(editor.text, "10.0.0.1/24");
        keyClick(Qt.Key_Tab);
        compare(panel.sources[1], "10.0.0.1/24");
        compare(panel.detailsNavigation.currentTarget, field(panel, 2));
        verify(panel.detailsNavigation.editing);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget, editor);
        verify(editor.inputActiveFocus);
    }
    function test_invalidDraftAndAtomicRejection() {
        const panel = make(1);
        const editor = field(panel, 1);
        keyClick(Qt.Key_Return);
        paste("192.168.999.1/33");
        compare(editor.validationState, 0);
        compare(input(panel, 1).color, Ui.Theme.danger);
        for (const bad of ["fe80::1%eth0/64", "1.2.3.4/24/bad", "1.2.3.4" + " ".repeat(32767) + "/24", "1.2.3.4\n/24"]) {
            paste(bad);
            compare(editor.text, "192.168.999.1/33", "reject the entire payload");
        }
        keyClick(Qt.Key_Return);
        compare(panel.sources[1], "192.168.999.1/33");
        verify(editor.invalidDescription.length > 0);
        keyClick(Qt.Key_Return);
        paste("10.0.0.1");
        compare(editor.text, "10.0.0.1/");
        compare(editor.validationState, 1);
        keyClick(Qt.Key_Tab);
        verify(!editor.inputValid, "missing subnet becomes invalid on explicit save without trapping Tab");
        compare(panel.detailsNavigation.currentTarget, field(panel, 2));
    }
    function test_addressOnlyRejectsSubnetAndLettersPreserveSelection() {
        const panel = make(0);
        const editor = field(panel, 0);
        keyClick(Qt.Key_Return);
        paste("192.0.2.1");
        paste("192.0.2.1/24");
        compare(editor.text, "192.0.2.1");
        keyClick(Qt.Key_G);
        compare(editor.text, "192.0.2.1");
        compare(input(panel, 0).selectedText, "192.0.2.1");
        keyClick(Qt.Key_Delete);
        keyClick(Qt.Key_Return);
        compare(panel.sources[0], "", "optional empty is not a zero address");
    }
    function test_ipv6NativePunctuationAndHex() {
        const panel = make(4);
        const editor = field(panel, 4);
        keyClick(Qt.Key_Return);
        type("2001:db8::1");
        keyClick(Qt.Key_Slash);
        type("129");
        compare(editor.text, "2001:db8::1/129");
        compare(editor.validationState, 0);
        keyClick(Qt.Key_Backspace);
        type("8");
        compare(editor.text, "2001:db8::1/128");
        keyClick(Qt.Key_Return);
        compare(panel.sources[4], "2001:db8::1/128");
        keyClick(Qt.Key_Return);
        input(panel, 4).select(5, 8);
        paste("ab:cd", false);
        compare(editor.text, "2001:ab:cd::1/128", "IPv6 substrings replace only the native selection");
        paste("ab:cd");
        compare(editor.text, "2001:ab:cd::1/128", "the same incomplete full-value paste is rejected atomically");
        compare(panel.writes, 1);
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(editor.text, "2001:db8::1/128");
        input(panel, 4).select(4, 5);
        keyClick(Qt.Key_Delete);
        compare(editor.text, "2001db8::1/128", "IPv6 colons are editable native text");
        keyClick(Qt.Key_Escape);
        compare(editor.text, "2001:db8::1/128");
    }
    function test_snapshotPointerDiscardAndAvailability() {
        const panel = make(0);
        keyClick(Qt.Key_Return);
        paste("192.0.2.1");
        panel.sources = ["10.0.0.1", "", "", "", ""];
        compare(field(panel, 0).text, "192.0.2.1");
        mouseClick(input(panel, 3), 30, 20);
        compare(field(panel, 0).text, "10.0.0.1");
        verify(field(panel, 3).inputActiveFocus);
        type("::1");
        panel.locked = true;
        compare(panel.writes, 0);
        compare(field(panel, 3).text, "");
        compare(panel.detailsNavigation.availableFields().length, 0);
        panel.locked = false;
        panel.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return);
        paste("192.0.2.2");
        panel.blocked = true;
        compare(field(panel, 0).text, "10.0.0.1");
        compare(panel.writes, 0);
    }
    function test_emptyRequiredSaveRetainsRedSlots() {
        const panel = make(1);
        const editor = field(panel, 1);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Return);
        verify(!editor.inputValid);
        compare(input(panel, 1).text, ".../");
        compare(input(panel, 1).color, Ui.Theme.danger);
        verify(input(panel, 1).Accessible.description.includes("Invalid value"));
        compare(panel.writes, 0, "an empty required save never invents an address or prefix");
    }
    function test_nativeSelectionCutDeletionAndUndoAcrossSubnet() {
        const panel = make(1);
        const editor = field(panel, 1);
        const native = input(panel, 1);
        keyClick(Qt.Key_Return);
        paste("10.0.0.1/24");
        native.cursorPosition = 3;
        keyClick(Qt.Key_Backspace);
        compare(editor.text, "1.0.0.1/24");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        compare(editor.text, "10.0.0.1/24");
        native.cursorPosition = 2;
        keyClick(Qt.Key_Delete);
        compare(editor.text, "10..0.1/24");
        keyClick(Qt.Key_Z, Qt.ControlModifier);
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_X, Qt.ControlModifier);
        compare(editor.text, ".../");
        keyClick(Qt.Key_V, Qt.ControlModifier);
        compare(editor.text, "10.0.0.1/24");
        keyClick(Qt.Key_Home);
        keyClick(Qt.Key_End, Qt.ShiftModifier);
        compare(native.selectedText, "10.0.0.1/24");
        compare(panel.writes, 0);
        keyClick(Qt.Key_Up);
        compare(panel.detailsNavigation.currentTarget, editor);
        keyClick(Qt.Key_Escape);
        compare(editor.text, "");
    }
    function test_forwardReverseWrapAndNarrowIpv6Caret() {
        const panel = make(4);
        panel.width = 380;
        keyClick(Qt.Key_Return);
        paste("2001:0db8:1234:5678:9abc:def0:1234:5678/128");
        const native = input(panel, 4);
        keyClick(Qt.Key_End);
        const caret = native.positionToRectangle(native.cursorPosition);
        verify(caret.x >= 0 && caret.x <= native.width, "native horizontal scrolling reveals the caret");
        keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.currentTarget, field(panel, 0));
        verify(panel.detailsNavigation.editing);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget, field(panel, 4));
        verify(panel.detailsNavigation.editing);
        compare(panel.writes, 1);
    }
    function test_crossNotationMaskAndFamilyChange() {
        const panel = make(2);
        const editor = field(panel, 2);
        keyClick(Qt.Key_Return);
        paste("192.0.2.1/23");
        compare(editor.text, "192.0.2.1/23");
        keyClick(Qt.Key_Return);
        compare(editor.text, "192.0.2.1/255.255.254.0");
        keyClick(Qt.Key_Return);
        paste("192.0.2.1/255.0.255.0");
        compare(editor.validationState, 0);
        keyClick(Qt.Key_Escape);
        compare(editor.text, "192.0.2.1/255.255.254.0");
        keyClick(Qt.Key_Return);
        paste("10.0.0.1/24");
        editor.subnetNotation = "prefix";
        compare(panel.writes, 1, "configuration changes discard, never save");
        verify(!panel.detailsNavigation.editing);
    }
}
