pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui
import "../../launcher" as Apps

TestCase {
    id: tests
    name: "PanelRoles"
    when: windowShown
    visible: true
    width: 560
    height: 700
    Component { id: toggleFactory; Ui.ToggleRow { width: 250; title: "A deliberately long translated setting name that must wrap over several lines without shrinking the switch"; compact: true; checked: true; property int activations: 0; onClicked: activations++ } }
    Component { id: stripFactory; Ui.StatusPanel { width: 170; uiScale: 1; status: "A long operation failure must wrap without hiding the reason or covering the result list." } }
    Component { id: statusFactory; Ui.SaveStatusLabel { valid: true; error: ""; saving: true; text: "Saving…" } }
    Component { id: readingFactory; Apps.ApplicationResourceCapacity { width: 200; valueSize: 8; descriptor: ({objectName: "testResourceReading", valueText: "15.7 MiB", label: "Memory", detailText: "Measured", color: Ui.Theme.accent, available: true, icon: "memory"}) } }
    Component { id: messageFactory; Ui.PanelMessage { width: 240; text: "A detailed operation failure must remain visible and wrap instead of being elided to a short, ambiguous fragment." } }
    Component {
        id: formFactory
        Ui.PanelSurface {
            id: surface
            width: tests.width; height: tests.height
            chooserController: Ui.ChooserController { uiActive: true }
            navigationContent: column
            Column {
                id: column
                width: 300
                Ui.SectionHeading { objectName: "heading"; width: parent.width; title: "Settings"; helpText: "Routine guidance" }
                Ui.FormField {
                    objectName: "form"; width: parent.width; label: "A long translated field name"; stackedLabel: true
                    Ui.TextField { objectName: "editable"; width: parent.width; text: "Original" }
                }
                Ui.InlineStatus { width: parent.width; text: "Pending is not acknowledgement" }
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_compactSwitchRetainsSizeAndReadableDisabledLabels() {
        const row = createTemporaryObject(toggleFactory, tests);
        verify(waitForRendering(row));
        const track = findChild(row, "toggleTrack");
        compare(track.width, 52); compare(track.height, 32);
        tryVerify(() => row.implicitHeight > Ui.Theme.formHeight, 1000, "long labels expand the row");
        row.enabled = false;
        compare(row.opacity, 1, "unavailable controls do not fade their passive labels");
        compare(track.opacity, Ui.Theme.disabledOpacity);
        const saved = row.checked;
        row.Accessible.toggleAction();
        compare(row.checked, saved, "presentation does not bypass activation guards");
        compare(row.activations, 0);
        row.enabled = true;
        mouseClick(row, row.width - 32, row.height / 2);
        compare(row.activations, 1);
    }
    function test_messagesGrowAndPendingIsNotSuccess() {
        const status = createTemporaryObject(statusFactory, tests);
        compare(status.color, Ui.Theme.mutedText, "pending is not success");
        status.error = "Save failed";
        compare(status.color, Ui.Theme.danger);
        const message = createTemporaryObject(messageFactory, tests);
        verify(waitForRendering(message));
        verify(message.implicitHeight > 2 * Ui.Theme.cardPadding + Ui.Theme.statusTextSize * 2);
        const oldHeight = message.implicitHeight;
        message.width = 140;
        tryVerify(() => message.implicitHeight > oldHeight);
        message.text = "";
        compare(message.implicitHeight, 0);
        const strip = createTemporaryObject(stripFactory, tests);
        verify(waitForRendering(strip));
        verify(strip.height > Ui.Theme.statusHeight, "list feedback grows, rather than eliding failures");
        const stripHeight = strip.height;
        strip.width = 120;
        tryVerify(() => strip.height > stripHeight);
    }
    function test_stackedLabelAndResourceReadingFloor() {
        const surface = createTemporaryObject(formFactory, tests);
        verify(waitForRendering(surface));
        const form = findChild(surface, "form");
        const field = findChild(surface, "editable");
        const label = findChild(form, "formFieldStackedLabel");
        verify(label.visible);
        verify(!findChild(form, "formFieldLabel").visible);
        verify(field.mapToItem(form, 0, 0).y >= label.implicitHeight + Ui.Theme.spacingXs);
        compare(field.Accessible.name, form.label);
        compare(surface.detailsNavigation.availableFields().length, 1);
        const reading = createTemporaryObject(readingFactory, tests);
        const value = findChild(reading, "resourceValue");
        compare(value.font.pixelSize, Ui.Theme.resourceValueMinimumSize);
        compare(value.minimumPixelSize, Ui.Theme.resourceValueMinimumSize);
    }
    function test_headingHelpRemainsACommandAndStatusIsNotAnEditor() {
        const surface = createTemporaryObject(formFactory, tests);
        const field = findChild(surface, "editable");
        const heading = findChild(surface, "heading");
        surface.detailsNavigation.focusContent(true);
        tryCompare(surface.detailsNavigation, "currentTarget", field);
        compare(surface.detailsNavigation.availableFields().length, 1);
        mouseClick(findChild(heading, "sectionHeadingHelp"));
        verify(heading.helpOpen);
        surface.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_End); keyClick(Qt.Key_X);
        keyClick(Qt.Key_Escape);
        compare(field.text, "Original");
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, field);
        compare(surface.detailsNavigation.availableFields().length, 1);
    }
}
