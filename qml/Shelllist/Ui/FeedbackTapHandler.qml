import QtQuick

// Passive tap observation preserves native editors, switches and flick gestures.
// The owning page supplies one source so a new disclosure replaces the old one.
TapHandler {
    property FeedbackSource feedback: null
    property string feedbackText: ""
    property string feedbackSummary: feedbackText
    property string feedbackBrief: feedbackSummary
    enabled: feedback !== null && feedbackText.length > 0
    gesturePolicy: TapHandler.DragThreshold
    function disclose(): void {
        if (!feedback) return;
        feedback.text = feedbackText;
        feedback.summaryText = feedbackSummary;
        feedback.briefText = feedbackBrief;
    }
    onTapped: disclose()
}
