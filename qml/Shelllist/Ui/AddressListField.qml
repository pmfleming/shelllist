import QtQuick
import "IpValidation.js" as IpValidation

TextEditor {
    property string family: "ipv4"
    property bool allowEmpty: true
    property bool validationAttempted: false
    readonly property int validationState: IpValidation.addressInputState(text, family, true, allowEmpty)
    // State stays live; user-facing errors start only at an explicit field save.
    errorText: validationAttempted && validationState !== IpValidation.Acceptable ? message(IpValidation.invalidIssue(text, family, true, false)) : ""
    supportingText: qsTr("Comma or whitespace separated")
    font.family: Theme.iconFontFamily
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
    onEditFinished: function (saved) {
        if (saved)
            validationAttempted = true;
    }
    onReadOnlyChanged: if (readOnly)
        validationAttempted = false
    onFamilyChanged: validationAttempted = false

    function message(issue: var): string {
        // Retain the former validation owner's translation context.
        switch (issue.key) {
        case "buffer":
            return qsTranslate("FieldValidation", "Input is too long; replace it with a complete value");
        case "cidr":
            return qsTranslate("FieldValidation", "Enter addresses without CIDR prefixes or subnet masks");
        case "zone":
            return qsTranslate("FieldValidation", "Scoped IPv6 addresses are not supported here");
        case "brackets":
            return qsTranslate("FieldValidation", "Enter an address without brackets or a port");
        case "length":
            return qsTranslate("FieldValidation", "Use at most %1 characters").arg(issue.maximum);
        case "empty-list-item":
            return qsTranslate("FieldValidation", "Enter an address after each comma");
        case "octet":
            return qsTranslate("FieldValidation", "Address %1: octet %2 must be 0–255").arg(issue.index).arg(issue.octet);
        default:
            const familyName = IpValidation.normalizedFamily(family) === "ipv6" ? "IPv6" : "IPv4";
            return qsTranslate("FieldValidation", "Address %1: enter a complete %2 address").arg(issue.index).arg(familyName);
        }
    }
}
