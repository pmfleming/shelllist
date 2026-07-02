import QtQuick
Loader {
    required property bool loadWhen; required property Component content
    anchors.fill: parent; active: loadWhen; sourceComponent: content
}
