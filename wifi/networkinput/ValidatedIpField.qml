import QtQuick
import Shelllist.Ui as Ui
import "IpValidation.js" as IpValidation

Ui.TextField {
    id: field
    property string family: "ipv4"
    property bool allowEmpty: false
    property bool multiple: false
    property bool prefixLength: false
    property alias validationAttempted: validation.attempted
    readonly property int validationState: validation.state
    inputValid: !validationAttempted || validationState === IpValidation.Acceptable
    errorText: validation.errorText
    // A generous native editing buffer retains invalid suffixes for validation.
    // Accepted lengths live in IpValidation, never in a truncating paste mask.
    maximumLength: IpValidation.MaximumEditingLength
    onEditingFinished: validation.attempted = true
    onReadOnlyChanged: if (readOnly)
        validation.attempted = false
    FieldValidation {
        id: validation
        text: field.text
        family: field.family
        allowEmpty: field.allowEmpty
        multiple: field.multiple
        prefixLength: field.prefixLength
    }
}
