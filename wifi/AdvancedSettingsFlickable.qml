import QtQuick
import Shelllist.Ui

// Keep the existing page-owned column/extent, with shared scroll memory and
// keyboard target revelation rather than a separate unregistered viewport.
DetailFlickable {
    anchors.fill: parent
}
