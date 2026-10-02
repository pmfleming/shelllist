pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Always-visible grouping. Information stays readable without becoming a
// keyboard browsing stop; sections containing settings retain their controls.
Column {
    id: section
    property string title: ""
    property bool informationOnly: false
    default property alias content: body.data
    width: parent ? parent.width : implicitWidth
    Layout.minimumHeight: implicitHeight
    spacing: Theme.spacingSm

    ThemeText {
        width: parent.width
        visible: section.title.length > 0
        text: section.title
        font.pixelSize: Theme.fontSizeHeading
        font.weight: Theme.fontWeightMedium
        wrapMode: Text.WordWrap
    }
    ColumnLayout {
        id: body
        width: parent.width
        spacing: Theme.spacingMd
    }
}
