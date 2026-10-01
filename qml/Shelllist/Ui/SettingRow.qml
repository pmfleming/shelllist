import QtQuick
import QtQuick.Layouts

// Passive list anatomy; the trailing native control keeps browse/edit ownership.
Item {
    id: row
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.mutedText
    property bool separatorVisible: true
    default property alias controls: trailing.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, Math.max(labels.implicitHeight, trailing.implicitHeight) + 2 * Theme.spacingSm)

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingSm
        anchors.bottomMargin: Theme.spacingSm
        spacing: Theme.spacingLg
        Column {
            id: labels
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            ThemeText {
                width: parent.width
                text: row.title
                font.pixelSize: Theme.fontSizeHeading
                wrapMode: Text.WordWrap
            }
            ThemeText {
                width: parent.width
                visible: row.subtitle.length > 0
                text: row.subtitle
                color: row.subtitleColor
                font.pixelSize: Theme.fontSizeLabel
                wrapMode: Text.WordWrap
            }
        }
        RowLayout {
            id: trailing
            spacing: Theme.spacingSm
        }
    }
    Rectangle {
        visible: row.separatorVisible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.withAlpha(Theme.border, 0.55)
    }
}
