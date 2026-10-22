import QtQuick
import QtQuick.Layouts

// Passive heading/description; Help is a named command, never a field stop.
ColumnLayout {
    id: heading
    property string title: ""
    property string helpText: ""
    property bool helpOpen: false
    property FeedbackSource helpFeedback: null
    property string helpObjectName: "sectionHeadingHelp"
    spacing: Theme.spacingSm

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        ThemeText {
            objectName: "sectionHeadingText"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: heading.title
            textFormat: Text.PlainText
            font.pixelSize: Theme.groupHeadingSize
            font.weight: Theme.groupHeadingWeight
            wrapMode: Text.Wrap
        }
        FeedbackButton {
            objectName: heading.helpObjectName
            feedback: heading.helpFeedback
            feedbackText: heading.helpText
            visible: heading.helpText.length > 0
            Layout.preferredWidth: Theme.formActionSize
            Layout.preferredHeight: Theme.formActionSize
            iconSize: Theme.formActionIconSize
            icon: heading.helpOpen ? "expand_less" : "help_outline"
            accessibleName: qsTr("Help: %1").arg(heading.title)
            Accessible.description: heading.helpText
            onClicked: if (!heading.helpFeedback) heading.helpOpen = !heading.helpOpen
        }
    }
    InlineStatus {
        Layout.fillWidth: true
        visible: !heading.helpFeedback && heading.helpOpen && text.length > 0
        text: heading.helpText
    }
}
