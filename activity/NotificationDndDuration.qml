import QtQuick
import Shelllist.Ui as Ui

Ui.ActionButton {
    required property NotificationState notificationState

    implicitWidth: 68
    implicitHeight: 34
    objectName: "notificationDndDuration"
    label: notificationState.dndDurationMinutes > 0 ? notificationState.dndDurationMinutes + " min" : "∞"
    toolTip: "DND duration: " + (notificationState.dndDurationMinutes > 0 ? notificationState.dndDurationMinutes + " minutes" : "indefinite") + " · click to cycle 30 min / 60 min / indefinite"
    Accessible.name: toolTip
    onClicked: notificationState.cycleDndDuration()
}
