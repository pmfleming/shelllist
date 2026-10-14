import QtQuick
import Shelllist.Ui as Ui
import "BarStatusPresentation.js" as Presentation

BarAction {
    id: clock
    required property date now
    required property var timezone
    required property int layoutDensity
    readonly property var descriptor: Presentation.clockModule(now, timezone)
    readonly property var clockParts: Presentation.clockParts(now, timezone)
    text: ""
    implicitWidth: clockText.implicitWidth + 14
    accessibleName: qsTr("Open time and weather") + ". " + descriptor.tooltip
    radius: 9
    Row {
        id: clockText
        anchors.centerIn: parent
        spacing: 8
        Ui.ThemeText {
            objectName: "barClock"
            anchors.verticalCenter: parent.verticalCenter
            text: clock.clockParts.time
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
            Accessible.ignored: true
        }
        Ui.ThemeText {
            objectName: "barClockDate"
            anchors.verticalCenter: parent.verticalCenter
            visible: clock.layoutDensity < 2
            text: clock.clockParts.shortDate
            font.pixelSize: Ui.Theme.fontSizeCaption
            color: Ui.Theme.mutedText
            Accessible.ignored: true
        }
    }
}
