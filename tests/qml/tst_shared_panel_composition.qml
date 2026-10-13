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
    function init() { failOnWarning(/.*/); }
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
