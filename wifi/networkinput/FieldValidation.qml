import QtQuick
import "IpValidation.js" as IpValidation

// State remains live, but user-facing errors start at an explicit field save.
QtObject {
    property string text: ""
    property string family: "ipv4"
    property bool allowEmpty: false
    property bool multiple: false
    property bool prefixLength: false
    property bool attempted: false
    readonly property int state: prefixLength ? IpValidation.prefixState(text, family, allowEmpty) : IpValidation.addressInputState(text, family, multiple, allowEmpty)
    readonly property string errorText: attempted && state !== IpValidation.Acceptable ? message(IpValidation.invalidIssue(text, family, multiple, prefixLength)) : ""
    onFamilyChanged: attempted = false

    function message(issue: var): string {
        switch (issue.key) {
        case "buffer":
            return qsTr("Input is too long; replace it with a complete value");
        case "prefix":
            return qsTr("Enter a prefix length from 0 to %1").arg(issue.maximum);
        case "cidr":
            return qsTr("Use the separate Prefix length field for CIDR notation");
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
            const familyName = IpValidation.normalizedFamily(family) === "ipv6" ? "IPv6" : "IPv4";
            return multiple ? qsTr("Address %1: enter a complete %2 address").arg(issue.index).arg(familyName) : qsTr("Enter a complete %1 address").arg(familyName);
        }
    }
}
