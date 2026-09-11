import QtQuick

ThemeText {
    // The parent owns geometry: use width/height in a positioner or layout,
    // and explicit anchors.fill for an overlay. No default parent anchors here.
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.Wrap
    clip: true
    color: Theme.mutedText
}
