pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Rectangle {
    id: card

    required property string title
    required property var segments
    required property real uiScale
    readonly property real total: segments.reduce(function (sum, segment) {
        return sum + Math.max(0, Number(segment.value || 0));
    }, 0)

    width: parent ? parent.width : 0
    height: Math.round(92 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(11 * card.uiScale)
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: card.title
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Text {
                text: Resources.bytes(card.total)
                color: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }

        Row {
            id: barRow
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            spacing: 2

            Repeater {
                model: card.segments
                delegate: Rectangle {
                    required property var modelData
                    height: parent.height
                    width: card.total > 0
                        ? Math.max(2, (barRow.width - Math.max(0, card.segments.length - 1) * barRow.spacing)
                            * Number(modelData.value || 0) / card.total) : 0
                    radius: 3
                    color: modelData.color
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: card.segments
                delegate: RowLayout {
                    id: legend
                    required property var modelData
                    spacing: 4
                    Rectangle {
                        Layout.preferredWidth: 7
                        Layout.preferredHeight: 7
                        radius: 4
                        color: legend.modelData.color
                    }
                    Text {
                        text: legend.modelData.label + " " + Resources.bytes(legend.modelData.value)
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
        }
    }
}
