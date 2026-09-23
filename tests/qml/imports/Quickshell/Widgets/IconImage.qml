import QtQuick

// Geometry-only icon for offscreen interaction tests, not renderer evidence.
Item {
    property url source
    property real implicitSize: 16
    implicitWidth: implicitSize
    implicitHeight: implicitSize
}
