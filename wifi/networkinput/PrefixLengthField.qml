import QtQuick
import "IpValidation.js" as IpValidation

ValidatedIpField {
    validationState: IpValidation.prefixState(text, family, allowEmpty)
    inputMethodHints: Qt.ImhDigitsOnly
    maximumLength: 3
    placeholder: family === "ipv6" ? "0–128" : "0–32"
}
