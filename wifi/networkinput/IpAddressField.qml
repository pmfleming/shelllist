import QtQuick
import Shelllist.Ui as Ui

ValidatedIpField {
    allowEmpty: true
    fontFamily: Ui.Theme.iconFontFamily
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    placeholder: multiple ? (family === "ipv6" ? "2001:4860:4860::8888, 2606:4700:4700::1111" : "1.1.1.1, 8.8.8.8") : (family === "ipv6" ? "2001:db8::20" : "192.168.1.20")
}
