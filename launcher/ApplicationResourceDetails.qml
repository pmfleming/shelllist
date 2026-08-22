pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

ColumnLayout {
    id: details

    required property var resource
    required property bool historical
    required property real uiScale
    property bool expanded: false
    readonly property var groups: Resources.detailGroups(resource, historical)

    width: parent ? parent.width : 0
    spacing: Math.round(Ui.Theme.spacingSm * uiScale)

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(42 * details.uiScale)
        radius: Ui.Theme.cardRadius
        color: pointer.containsMouse ? Ui.Theme.hover : Ui.Theme.surface
        border.color: details.expanded ? Ui.Theme.accent : Ui.Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Technical details"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Text {
                text: details.expanded ? "󰅀" : "󰅂"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.iconFontFamily
                font.pixelSize: Ui.Theme.iconSize
            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: details.expanded = !details.expanded
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: details.expanded
        spacing: Math.round(Ui.Theme.spacingMd * details.uiScale)

        Repeater {
            model: details.groups

            delegate: ColumnLayout {
                id: group
                required property var modelData
                Layout.fillWidth: true
                spacing: Math.round(Ui.Theme.spacingSm * details.uiScale)

                Ui.SectionLabel { text: group.modelData.title }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Math.round(Ui.Theme.spacingLg * details.uiScale)
                    rowSpacing: Math.round(Ui.Theme.spacingSm * details.uiScale)

                    Repeater {
                        model: group.modelData.fields
                        delegate: Ui.DetailField {
                            required property var modelData
                            Layout.fillWidth: true
                            width: Math.max(150, (group.width - Ui.Theme.spacingLg) / 2)
                            valueWidth: width
                            label: modelData.label
                            value: modelData.value
                        }
                    }
                }
            }
        }
    }
}
