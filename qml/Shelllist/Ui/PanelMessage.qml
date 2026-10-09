import QtQuick
import QtQuick.Layouts

// A panel-wide message, not a field boundary or a recovery/request owner.
Rectangle {
    id: message
    property alias text: label.text
    property alias tone: label.tone
    property real padding: Theme.cardPadding
    visible: label.text.length > 0
    implicitHeight: visible ? label.implicitHeight + 2 * padding : 0
    Layout.minimumHeight: implicitHeight
    radius: Theme.formRadius
    color: tone === "error" ? Theme.dangerBackground : tone === "warning" ? Theme.withAlpha(Theme.warning, 0.12) : Theme.surfaceRaised

    InlineStatus {
        id: label
        x: message.padding
        y: message.padding
        width: Math.max(0, message.width - 2 * message.padding)
        tone: "error"
    }
}
