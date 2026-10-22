import QtQuick

// Explicit information disclosure into the owning surface's fixed status slot.
// Commands remain outside editable traversal; the owner clears stale context.
FlatIconButton {
    id: button
    property FeedbackSource feedback: null
    property string feedbackText: ""
    property string feedbackSummary: feedbackText
    property string feedbackBrief: feedbackSummary
    icon: "help_outline"
    Accessible.description: feedbackText
    onClicked: {
        if (!feedback) return;
        feedback.text = feedbackText;
        feedback.summaryText = feedbackSummary;
        feedback.briefText = feedbackBrief;
    }
}
