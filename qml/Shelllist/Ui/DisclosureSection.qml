import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: section

    property string title: ""
    property bool expanded: false
    default property alias content: body.data

    spacing: Theme.spacingMd

    ActionButton {
        objectName: "disclosureButton"
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.compactControlHeight
        label: section.title
        icon: section.expanded ? "󰅀" : "󰅂"
        accessibleName: (section.expanded ? "Collapse " : "Expand ") + section.title
        onClicked: section.expanded = !section.expanded
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: section.expanded
        spacing: Theme.spacingSm
    }
}
