pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Read-only resource value. Only composition cards opt into a bar; memory and
// activity values have no implied capacity denominator or severity indicator.
Rectangle {
    id: capacity

    required property string label
    required property string valueText
    property string detailText: ""
    property color accentColor: Ui.Theme.resourceCpu
    property real uiScale: 1
    property bool available: true
    property var segments: []
    readonly property real total: segments.reduce(function (sum, segment) {
        return sum + Math.max(0, Number(segment.value) || 0);
    }, 0)

    implicitHeight: content.implicitHeight + 24 * uiScale
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.mix(Ui.Theme.surfaceRaised, accentColor, Ui.Theme.dark ? 0.06 : 0.03)
    Accessible.role: Accessible.StaticText
    Accessible.name: label + ": " + (available ? valueText : qsTr("Unavailable")) + ". " + detailText

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Math.round(12 * capacity.uiScale)
        spacing: Ui.Theme.spacingSm

        Ui.ThemeText {
            Layout.fillWidth: true
            text: capacity.label
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        Ui.ThemeText {
            objectName: "resourceValue"
            Layout.fillWidth: true
            text: capacity.available ? capacity.valueText : "—"
            color: capacity.available ? capacity.accentColor : Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightBold
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: capacity.detailText
            color: Ui.Theme.mutedText
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(6 * capacity.uiScale)
            visible: capacity.available && capacity.segments.length > 0 && capacity.total > 0
            Repeater {
                model: capacity.segments
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width * Math.max(0, Number(modelData.value) || 0) / Math.max(1, capacity.total)
                    height: parent.height
                    color: modelData.color
                }
            }
        }
    }
}
