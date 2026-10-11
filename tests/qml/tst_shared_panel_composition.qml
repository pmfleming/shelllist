import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "SharedPanelComposition"
    visible: true
    when: windowShown
    width: 560
    height: 360

    Component {
        id: feedbackFactory
        Ui.FeedbackSlot {
            width: 160
            text: "A deliberately long diagnostic. ".repeat(30)
            summaryText: "An overlong translated summary. ".repeat(10)
        }
    }
    Component {
        id: toggleFactory
        Ui.ToggleRow {
            title: "Adaptive hardware tuning"
            subtitle: "Panel power savings (may affect colour quality)"
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_toggleLabelsUseSpaceBeforeSwitch_data() {
        return [
            {tag: "narrow-icon", rowWidth: 340, icons: ["tune"]},
            {tag: "wide-icon", rowWidth: 520, icons: ["tune"]},
            {tag: "narrow-text", rowWidth: 340, icons: []}
        ];
    }
    function test_toggleLabelsUseSpaceBeforeSwitch(data) {
        const row = createTemporaryObject(toggleFactory, tests, {width: data.rowWidth, icons: data.icons});
        verify(waitForRendering(row));
        const label = findChild(row, "fieldRowLabel");
        const subtitle = findChild(row, "fieldRowSubtitle");
        const right = label.mapToItem(row, label.width, 0).x;
        compare(Math.round(right + Ui.Theme.spacingMd), Math.round(row.focusSurface.mapToItem(row, 0, 0).x));
        compare(Math.round(row.focusSurface.mapToItem(row, row.focusSurface.width, 0).x), data.rowWidth);
        compare(label.width, subtitle.width);
        verify(label.width > Ui.Theme.fieldLabelWidth(row.width));
        compare(label.lineCount, 1, "ordinary titles do not wrap into a narrow column");
        compare(label.font.pixelSize, Ui.Theme.fieldNameSize);
        compare(row.focusSurface.width, 64, "switch hit geometry is unchanged");
        row.title = "A much longer translated hardware tuning label ".repeat(3);
        verify(waitForRendering(row));
        verify(label.lineCount > 1);
        verify(label.mapToItem(row, 0, label.height).y <= row.height);
        verify(subtitle.mapToItem(row, 0, subtitle.height).y <= row.height);
        compare(row.focusSurface.width, 64);
    }
    function test_overlongSummaryKeepsFullDiagnosticAndReadableFallback() {
        const slot = createTemporaryObject(feedbackFactory, tests);
        verify(waitForRendering(slot));
        tryCompare(slot, "displayText", "Check status");
        compare(slot.Accessible.name, slot.text);
        compare(slot.height, Ui.Theme.statusHeight);
        const label = findChild(slot, "feedbackText");
        compare(label.font.pixelSize, Ui.Theme.statusTextSize);
        verify(label.contentHeight <= label.height + 1);
    }
}
