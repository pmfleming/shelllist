import QtQuick

ValidatedIpField {
    prefixLength: true
    prefix: "/"
    supportingText: family === "ipv6" ? "0–128" : "0–32"
    inputMethodHints: Qt.ImhDigitsOnly
    placeholder: family === "ipv6" ? "0–128" : "0–32"
}
