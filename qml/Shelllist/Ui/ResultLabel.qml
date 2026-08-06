import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: label

    required property string title
    property string subtitle: ""
    property color titleColor: Theme.text
    property color subtitleColor: Theme.subtleText
    property bool statusIndicatorVisible: false
    property color statusIndicatorColor: subtitleColor
    property int titleWeight: Theme.fontWeightRegular
    property int subtitleWeight: Theme.fontWeightRegular
    property real uiScale: 1
    property int titlePixelSize: Math.max(Theme.fontSizeSmall, Math.round(Theme.fontSizeLabel * uiScale))
    property int subtitlePixelSize: Math.max(10, Math.round(Theme.fontSizeCaption * uiScale))

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Math.max(1, Math.round(2 * uiScale))

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        verticalAlignment: Text.AlignBottom
        text: label.title
        color: label.titleColor
        font.family: Theme.fontFamily
        font.pixelSize: label.titlePixelSize
        font.weight: label.titleWeight
        elide: Text.ElideRight
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Math.max(Theme.spacingXs, Math.round(Theme.spacingSm * label.uiScale))

        Rectangle {
            visible: label.statusIndicatorVisible
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: width / 2
            color: label.statusIndicatorColor
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
            text: label.subtitle
            color: label.subtitleColor
            font.family: Theme.fontFamily
            font.pixelSize: label.subtitlePixelSize
            font.weight: label.subtitleWeight
            elide: Text.ElideRight
        }
    }
}
