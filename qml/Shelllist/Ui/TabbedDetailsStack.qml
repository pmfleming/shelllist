import QtQuick

Item {
    id: stack

    default property alias pages: viewport.data
    required property int footerHeight
    property int sectionSpacing: Theme.spacingMd
    property string selectedValue: ""
    property var tabs: []

    signal selected(string value)

    Item {
        id: viewport
        anchors.top: parent.top
        width: parent.width
        height: Math.max(0, parent.height - stack.footerHeight - stack.sectionSpacing)
        clip: true
    }

    DetailsTabBar {
        anchors.bottom: parent.bottom
        width: parent.width
        height: stack.footerHeight
        selectedValue: stack.selectedValue
        tabs: stack.tabs
        onSelected: function (value) { stack.selected(value); }
    }
}
