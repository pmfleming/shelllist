import QtQuick
import Shelllist.Ui as Ui
import "IpValidation.js" as IpValidation

Ui.TextField {
    property string family: "ipv4"
    property bool allowEmpty: false
    readonly property int maximumPrefix: family === "ipv6" ? 128 : 32
    readonly property int validationState: IpValidation.prefixState(text, family, allowEmpty)
    readonly property bool acceptableInput: validationState === IpValidation.Acceptable
    readonly property bool intermediateInput: validationState === IpValidation.Intermediate

    inputValid: validationState !== IpValidation.Invalid
    inputMethodHints: Qt.ImhDigitsOnly
    maximumLength: 3
    placeholder: family === "ipv6" ? "0–128" : "0–32"
}
