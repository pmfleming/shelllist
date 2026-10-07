import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui

TestCase {
    name: "MaterialFields"
    when: windowShown
    visible: true
    width: 500
    height: 320

    Component {
        id: fieldFactory
        Ui.TextField {
            width: 300
            text: "secret"
            password: true
            trailingActionIcon: "+"
            trailingActionToolTip: "Extra action"
            Accessible.name: "Credential"
        }
    }
    Component {
        id: choiceFactory
        Ui.DropDownList {
            width: 300
            value: "first"
            options: [
                { value: "first", label: "First" },
                { value: "disabled", label: "Unavailable", enabled: false },
                { value: "third", label: "Third" }
            ]
        }
    }
    SignalSpy {
        id: edits
        signalName: "edited"
    }
    SignalSpy {
        id: intent
    }
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = { SHELLLIST_NO_ANIMATIONS: "false" };
    }
    function cleanup() {
        edits.target = null;
        intent.target = null;
        Quickshell.environment = ({});
    }

    function test_fieldRetainsNativeEditingAndGuardedSecretActions() {
        const field = createTemporaryObject(fieldFactory, this);
        const input = findChild(field, "fieldInput");
        const reveal = findChild(field, "passwordVisibilityAction");
        const trailing = findChild(field, "fieldTrailingAction");
        const ring = findChild(field, "focusRing");
        edits.target = field;
        edits.clear();
        intent.signalName = "trailingActionRequested";
        intent.target = field;
        intent.clear();
        compare(input.Accessible.name, "Credential");
        compare(input.echoMode, TextInput.Password);
        verify(input.displayText !== field.text);
        field.focusInput(false);
        field.cursorPosition = 2;
        keyClick(Qt.Key_Left);
        compare(field.cursorPosition, 1);
        keyClick(Qt.Key_X);
        compare(field.text, "sxecret");
        compare(edits.count, 1);
        const height = field.height;
        field.inputValid = false;
        const errorIcon = findChild(field, "fieldErrorIcon");
        verify(errorIcon.visible);
        compare(errorIcon.symbol, "error");
        compare(errorIcon.font.family, Ui.Theme.symbolFontFamily);
        verify(input.activeFocus && ring.visible);
        compare(ring.border.width, 2);
        compare(String(ring.color), String(Ui.Theme.withAlpha(Ui.Theme.danger, 0.22)));
        compare(String(field.border.color), String(Ui.Theme.danger));
        compare(field.height, height);
        field.inputValid = true;
        compare(String(ring.color), String(Ui.Theme.withAlpha(Ui.Theme.accent, 0.22)));
        compare(String(field.border.color), String(Ui.Theme.accent));
        field.readOnly = true;
        keyClick(Qt.Key_X);
        compare(edits.count, 1);
        reveal.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(field.passwordRevealed);
        compare(input.echoMode, TextInput.Normal);
        field.visible = false;
        verify(!field.passwordRevealed);
        compare(input.echoMode, TextInput.Password);
        field.visible = true;
        field.enabled = false;
        reveal.Accessible.pressAction();
        trailing.Accessible.pressAction();
        verify(!field.passwordRevealed);
        compare(intent.count, 0);
        field.enabled = true;
        field.trailingActionEnabled = false;
        trailing.Accessible.pressAction();
        compare(intent.count, 0);
        field.trailingActionEnabled = true;
        trailing.Accessible.pressAction();
        compare(intent.count, 1);
        compare(edits.count, 1, "embedded actions do not rewrite the editor");
    }

    function test_dropdownHoverFocusAndAcknowledgedSelection() {
        const control = createTemporaryObject(choiceFactory, this);
        intent.signalName = "selected";
        intent.target = control;
        intent.clear();
        control.forceActiveFocus();
        mouseMove(control, 20, control.height / 2);
        compare(control.background.color.a, 0, "value rows keep their low-chrome base; hover/focus paint is local");
        verify(findChild(control.background, "focusRing").visible);
        keyClick(Qt.Key_Space);
        tryCompare(control.popup, "visible", true);
        compare(control.popup.opacity, 1, "popup focus cannot wait for a fade");
        let third = null;
        tryVerify(() => {
            third = findChild(control.popup.contentItem, "dropDownOption-2");
            return third !== null;
        });
        const first = findChild(control.popup.contentItem, "dropDownOption-0");
        const highlighted = control.highlightedIndex;
        mouseMove(third, third.width / 2, third.height / 2);
        wait(30);
        compare(control.highlightedIndex, highlighted, "hover cannot redirect keyboard activation");
        compare(control.value, "first");
        compare(third.width, control.popup.availableWidth);
        verify(first.Accessible.selected);
        keyClick(Qt.Key_End);
        compare(control.highlightedIndex, 2);
        verify(findChild(third, "focusRing").visible);
        compare(String(third.contentItem.color), String(Ui.Theme.accentText));
        compare(String(first.contentItem.color), String(Ui.Theme.selectedText));
        keyClick(Qt.Key_Return);
        compare(intent.count, 1);
        compare(intent.signalArguments[0][0], "third");
        compare(control.value, "first");
        compare(control.contentItem.text, "First", "native candidate is not a daemon acknowledgement");
        control.value = "third";
        compare(control.contentItem.text, "Third");
        control.forceActiveFocus();
        keyClick(Qt.Key_Space);
        tryCompare(control.popup, "visible", true);
        keyClick(Qt.Key_Escape);
        tryCompare(control.popup, "visible", false);
        compare(control.value, "third");
        compare(intent.count, 1, "Escape cancels browsing without another request");
        control.activated(1);
        compare(intent.count, 1, "unavailable choices never dispatch");
        control.interactive = false;
        control.activated(0);
        compare(intent.count, 1, "late activation while busy never dispatches");
        control.interactive = true;
        control.enabled = false;
        control.activated(0);
        compare(intent.count, 1);
    }
}
