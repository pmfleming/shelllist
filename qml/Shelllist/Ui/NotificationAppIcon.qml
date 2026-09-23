import Quickshell
import QtQuick

// App or image icon on a rounded tile, with an optional stack-count badge.
Rectangle {
    id: tile

    required property var notification
    property int count: 1
    readonly property string source: resolveSource()

    function resolveSource(): string {
        const hints = notification && notification.hints || ({});
        const candidate = String(hints.image_path || notification && notification.app_icon || "");
        if (candidate.startsWith("/"))
            return "file://" + candidate;
        if (candidate.startsWith("file://"))
            return candidate;
        return Quickshell.iconPath(candidate || "dialog-information", "dialog-information");
    }

    implicitWidth: 40
    implicitHeight: 40
    radius: Theme.controlRadius
    color: Theme.input

    Image {
        anchors.fill: parent
        anchors.margins: Math.round(tile.width * 0.15)
        source: tile.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }

    GroupCountBadge {
        count: tile.count
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -4
        anchors.bottomMargin: -4
    }
}
