pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Presentation only: keep children/drafts alive while hiding secondary content.
Column {
    id: section
    property string title: ""
    property bool expanded: false
    property bool attention: false
    readonly property bool open: expanded || attention
    default property alias content: body.data
    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingSm

    ActionButton {
        objectName: section.objectName ? section.objectName + "Toggle" : ""
        width: parent.width
        label: section.title
        icon: section.open ? "expand_less" : "expand_more"
        iconOnly: false
        Accessible.description: section.attention ? qsTr("Attention required") : section.open ? qsTr("Expanded") : qsTr("Collapsed")
        interactive: !section.attention
        onClicked: section.expanded = !section.expanded
    }
    ColumnLayout {
        id: body
        width: parent.width
        visible: section.open
        spacing: Theme.spacingMd
    }
}
