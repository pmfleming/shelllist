import QtQuick
import Shelllist.Ui as Ui

Ui.ActionButton {
    signal triggered
    width: 38
    height: 38
    iconSize: 24
    onClicked: triggered()
}
