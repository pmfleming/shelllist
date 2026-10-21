import QtQuick
import Shelllist.Ui as Ui

// State remains live, but user-facing errors start at an explicit field save.
QtObject {
    property string text: ""
    property string family: "ipv4"
    property bool allowEmpty: false
    property bool multiple: false
    property bool attempted: false
    readonly property int state: Ui.IpValidation.addressInputState(text, family, multiple, allowEmpty)
    readonly property string errorText: attempted && state !== Ui.IpValidation.Acceptable ? message(Ui.IpValidation.invalidIssue(text, family, multiple, false)) : ""
    onFamilyChanged: attempted = false

    function message(issue: var): string {
        switch (issue.key) {
        case "buffer":
            return qsTr("Input is too long; replace it with a complete value");
        case "cidr":
            return qsTr("Enter addresses without CIDR prefixes or subnet masks");
        case "zone":
            return qsTr("Scoped IPv6 addresses are not supported here");
        case "brackets":
            return qsTr("Enter an address without brackets or a port");
        case "length":
            return qsTr("Use at most %1 characters").arg(issue.maximum);
        case "empty-list-item":
            return qsTr("Enter an address after each comma");
        case "octet":
            return multiple ? qsTr("Address %1: octet %2 must be 0–255").arg(issue.index).arg(issue.octet) : qsTr("Octet %1 must be 0–255").arg(issue.octet);
        default:
            const familyName = Ui.IpValidation.normalizedFamily(family) === "ipv6" ? "IPv6" : "IPv4";
            return multiple ? qsTr("Address %1: enter a complete %2 address").arg(issue.index).arg(familyName) : qsTr("Enter a complete %1 address").arg(familyName);
        }
    }
}
