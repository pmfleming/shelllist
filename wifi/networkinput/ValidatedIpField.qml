import QtQuick
import Shelllist.Ui as Ui
import "IpValidation.js" as IpValidation

Ui.TextField {
    property string family: "ipv4"
    property bool allowEmpty: false
    property int validationState: IpValidation.Intermediate

    inputValid: validationState !== IpValidation.Invalid
}
