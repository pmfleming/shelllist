import QtQuick
import Shelllist.Ui as Ui

Item {
    required property string surfaceId
    required property string displayName
    required property string icon
    required property Ui.ChooserController controller
    required property Component content
}
