pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtTest
import Shelllist.Ui as Ui
import "../../activity" as Activity

TestCase {
    id: tests
    name: "SharedPanelComposition"
    visible: true
    when: windowShown
    width: 820
    height: 700
    Component {
        id: factory
        Ui.PanelSurface {
            width: 520; height: 650
            chooserController: Ui.ChooserController { uiActive: true }
            navigationContent: content
            Column {
                id: content
                width: parent.width
                Ui.FormField {
                    objectName: "choiceRow"; width: parent.width; label: "Mode"
                    Ui.SegmentedControl {
                        objectName: "choice"; Layout.fillWidth: true
                        options: [{value: "a", label: "One"}, {value: "b", label: "Two"}]
                        value: "a"
                    }
                }
                Ui.FormField {
                    width: parent.width; label: "Profile"
                    Ui.DropDownList { Layout.fillWidth: true; options: [{value: "a", label: "One"}]; value: "a" }
                }
                Ui.SettingRow {
                    objectName: "setting"; width: parent.width; title: "Radio"
                    subtitle: "Routine explanation is available through Help"
                    Ui.ToggleSwitch { checked: true }
                }
                Ui.LabeledValueSlider { width: parent.width; label: "Level"; value: 50 }
                Ui.ToggleRow { width: parent.width; title: "Enabled"; checked: true }
                Ui.FeedbackSlot { objectName: "slot"; width: parent.width; scope: content }
            }
        }
    }
    Component {
        id: narrowFeedbackFactory
        Ui.FeedbackSlot {
            width: 160
            text: "A deliberately long diagnostic. ".repeat(30)
            summaryText: "An overlong translated summary. ".repeat(10)
        }
    }
    Component {
        id: weatherFactory
        Activity.WeatherHero {
            width: 520
            weather: ({temperature_c: -18, high_c: -10, low_c: -21, condition_code: "clear", condition: "Clear", location: "Example", updated_unix_ms: 1})
        }
    }
    function init() { failOnWarning(/.*/); width = 820; }
    function descendants(item, type) {
        let result = item instanceof type ? [item] : [];
        for (const child of item.children) result = result.concat(descendants(child, type));
        return result;
    }
    function geometry(surface) {
        return surface.detailsNavigation.availableFields().map(field => {
            const p = field.mapToItem(surface, 0, 0);
            return [p.x, p.y, field.width, field.height].join(",");
        }).join(";");
    }
    function test_familyAlignmentAndStableFeedback() {
        const surface = createTemporaryObject(factory, tests);
        verify(waitForRendering(surface));
        const rows = descendants(surface, Ui.FieldRow);
        compare(rows.length, 5);
        for (const width of [340, 520, 760]) {
            tests.width = width;
            verify(waitForPolish(surface.Window.window));
            for (const row of rows) {
                compare(row.labelColumnWidth, Ui.Theme.fieldLabelWidth(width));
                compare(row.editorX, rows[0].editorX, "All editor families share the label/editor boundary");
            }
        }
        tests.width = 340;
        verify(waitForPolish(surface.Window.window));
        surface.detailsNavigation.focusContent(true);
        const choice = findChild(surface, "choice");
        compare(surface.detailsNavigation.currentTarget, choice);
        tryVerify(() => descendants(choice, Ui.FocusRing).some(item => item.visible));
        const ring = descendants(choice, Ui.FocusRing).find(item => item.visible);
        compare(ring.color.a, 0, "Browsing does not tint the editor");
        verify(findChild(ring, "browseFocusIndicator").visible);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Right);
        compare(choice.displayedValue, "b"); compare(choice.value, "a");
        const before = geometry(surface);
        const slot = findChild(surface, "slot");
        const form = findChild(surface, "choiceRow");
        const setting = findChild(surface, "setting");
        const diagnostic = "The service rejected the requested change. ".repeat(30);
        form.errorText = diagnostic;
        setting.subtitleColor = Ui.Theme.warning;
        setting.subtitle = diagnostic + "Radio";
        verify(waitForPolish(surface.Window.window));
        compare(geometry(surface), before, "Error and guidance transitions never move controls");
        compare(slot.height, Ui.Theme.statusHeight);
        verify(slot.Accessible.name.includes(diagnostic));
        const label = findChild(slot, "feedbackText");
        verify(label.contentHeight <= label.height + 1, "Concise feedback fits without shrinking");
        compare(label.font.pixelSize, Ui.Theme.statusTextSize);
        verify(surface.detailsNavigation.editing, "Feedback does not end a field-local draft");
        keyClick(Qt.Key_Escape);
        compare(choice.displayedValue, "a");
        form.errorText = ""; setting.subtitleColor = Ui.Theme.mutedText; setting.subtitle = "Routine explanation";
        verify(waitForPolish(surface.Window.window));
        compare(geometry(surface), before);
        compare(slot.height, Ui.Theme.statusHeight);
    }
    function test_overlongSummaryKeepsFullDiagnosticAndReadableFallback() {
        const slot = createTemporaryObject(narrowFeedbackFactory, tests);
        verify(waitForRendering(slot));
        tryCompare(slot, "displayText", "Check status");
        compare(slot.Accessible.name, slot.text);
        compare(slot.height, Ui.Theme.statusHeight);
        const label = findChild(slot, "feedbackText");
        compare(label.font.pixelSize, Ui.Theme.statusTextSize);
        verify(label.contentHeight <= label.height + 1);
    }
    function test_weatherOnlyEnlargesTemperature() {
        const hero = createTemporaryObject(weatherFactory, tests);
        verify(waitForRendering(hero));
        const metrics = findChild(hero, "weatherHeroMetrics");
        const originalY = metrics.y;
        for (const width of [360, 420, 600]) {
            hero.width = width;
            verify(waitForPolish(hero.Window.window));
            compare(hero.height, 192);
            compare(metrics.height, 48);
            compare(metrics.y, originalY, "No new whitespace or moved metric strip");
            const temperature = findChild(hero, "weatherCurrentTemperature");
            compare(temperature.font.pixelSize, width < 420 ? Ui.Theme.heroWeatherCompactSize : Ui.Theme.heroWeatherSize);
            verify(temperature.mapToItem(hero, 0, temperature.height).y <= metrics.y);
        }
    }
}
