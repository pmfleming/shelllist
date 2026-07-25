import QtQuick
import "IpValidation.js" as IpValidation

ValidatedIpField {
    property bool multiple: false

    allowEmpty: true
    validationState: IpValidation.addressInputState(text, family, multiple, allowEmpty)
    inputMethodHints: family === "ipv4" && !multiple
        ? Qt.ImhFormattedNumbersOnly
        : (Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase)
    maximumLength: multiple ? 512 : (family === "ipv6" ? 45 : 15)
    placeholder: multiple
        ? (family === "ipv6" ? "2001:4860:4860::8888, 2606:4700:4700::1111" : "1.1.1.1, 8.8.8.8")
        : (family === "ipv6" ? "2001:db8::20" : "192.168.1.20")
}
