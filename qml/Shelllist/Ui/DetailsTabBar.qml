pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: bar

    property var tabs: []
    property string selectedValue: ""
    signal selected(string value)

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: bar.tabs

            delegate: DetailsTab {
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: modelData.icon || ""
                label: modelData.label || ""
                selected: bar.selectedValue === modelData.value
                enabled: modelData.enabled === undefined || !!modelData.enabled
                onClicked: bar.selected(modelData.value)
            }
        }
    }
}
