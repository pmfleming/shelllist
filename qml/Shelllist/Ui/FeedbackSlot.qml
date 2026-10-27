pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// One fixed allocation per surface. Raw diagnostics remain accessible; concise
// owner-supplied summaries replace paragraphs, never shrink the font or controls.
Item {
    id: slot
    property Item scope: null
    property string text: ""
    property string summaryText: qsTr("Status needs attention")
    property string briefText: qsTr("Check status")
    property string tone: "info"
    property bool backgroundVisible: true
    property real padding: Theme.spacingSm
    // Presentation budgets follow the actual label, including shared padding.
    readonly property real textWidth: label.width
    readonly property var contributions: {
        const entries = collect(scope);
        if (text.length && !entries.some(entry => entry.text === text) && (tone !== "info" || entries.length === 0))
            entries.push({text: text, summary: summaryText, brief: briefText, tone: tone, priority: tone === "error" ? 40 : tone === "warning" ? 25 : 0});
        return entries.sort((a, b) => b.priority - a.priority);
    }
    readonly property string fullText: contributions.map(entry => entry.text).concat(text ? [text] : []).filter((value, index, list) => list.indexOf(value) === index).join(". ")
    readonly property string message: contributions.length ? contributions.map(entry => entry.text).join(" · ") : text
    readonly property string summary: contributions.length ? contributions[0].summary + (contributions.length > 1 ? " · " + qsTr("%n more", "", contributions.length - 1) : "") : summaryText
    readonly property string messageTone: contributions.length ? contributions[0].tone : tone
    readonly property string primarySummary: contributions.length ? contributions[0].summary : summaryText
    readonly property string compactSummary: contributions.length ? contributions[0].brief : briefText
    readonly property string displayText: rawMeasure.implicitHeight <= label.height ? message : summaryMeasure.implicitHeight <= label.height ? summary : primaryMeasure.implicitHeight <= label.height ? primarySummary : compactSummary

    implicitHeight: Theme.statusHeight
    implicitWidth: 200
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    Accessible.role: Accessible.StaticText
    Accessible.name: fullText

    function collect(root: Item): var {
        const result = [];
        function visit(item) {
            if (!item || item instanceof FeedbackSlot) return;
            if (item instanceof FeedbackSource) {
                if (item.active && item.text.length && !result.some(entry => entry.text === item.text))
                    result.push({text: item.text, summary: item.summaryText, brief: item.briefText, tone: item.tone, priority: item.priority});
                return;
            }
            if (!item.visible) return;
            for (const child of item.children) visit(child);
        }
        visit(root);
        return result.sort((a, b) => b.priority - a.priority);
    }

    Rectangle {
        anchors.fill: parent
        visible: slot.backgroundVisible && slot.fullText.length > 0
        radius: Theme.formRadius
        color: slot.messageTone === "error" ? Theme.dangerBackground : Theme.surfaceRaised
        Accessible.ignored: true
    }
    ThemeText {
        id: rawMeasure
        visible: false
        width: label.width
        font.pixelSize: Theme.statusTextSize
        text: slot.message
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
    ThemeText {
        id: summaryMeasure
        visible: false
        width: label.width
        font.pixelSize: Theme.statusTextSize
        text: slot.summary
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
    ThemeText {
        id: primaryMeasure
        visible: false
        width: label.width
        font.pixelSize: Theme.statusTextSize
        text: slot.primarySummary
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
    ThemeText {
        id: label
        objectName: "feedbackText"
        anchors.fill: parent
        anchors.leftMargin: slot.padding
        anchors.rightMargin: slot.padding
        anchors.topMargin: Theme.spacingXs
        anchors.bottomMargin: Theme.spacingXs
        text: slot.displayText
        textFormat: Text.PlainText
        font.pixelSize: Theme.statusTextSize
        color: slot.messageTone === "error" ? Theme.danger : slot.messageTone === "warning" ? Theme.warning : Theme.mutedText
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
        Accessible.ignored: true
    }
}
