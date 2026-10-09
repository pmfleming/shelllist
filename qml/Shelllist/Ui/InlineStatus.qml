import QtQuick

// Presentation only. Owners keep request, validation and acknowledgement state.
ThemeText {
    property string tone: "info"
    visible: text.length > 0
    font.pixelSize: Theme.statusTextSize
    color: tone === "error" ? Theme.danger : tone === "warning" ? Theme.warning : tone === "success" ? Theme.active : Theme.mutedText
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    elide: Text.ElideNone
    Accessible.role: Accessible.StaticText
}
