import Quickshell
import QtQuick

// Resolve only installed theme icons. Quickshell's missing-image URL can load
// successfully as a checkerboard, so Image.Error alone is not a safe fallback.
IconTile {
    id: tile

    required property var notification
    property int count: 1
    property real imageMargin: Math.round(width * 0.15)
    readonly property string source: resolveSource()

    function resolveSource(): string {
        const n = notification || ({});
        const hints = n.hints || ({});
        const candidates = [hints.image_path, n.app_icon, hints.desktop_entry,
            n.app_name, String(n.app_name || "").toLowerCase()];
        for (const value of candidates) {
            const candidate = String(value || "").trim();
            if (candidate.startsWith("/")) return "file://" + candidate;
            if (candidate.startsWith("file://")) return candidate;
            if (candidate && Quickshell.hasThemeIcon(candidate)) return Quickshell.iconPath(candidate);
        }
        return "";
    }

    implicitWidth: 40
    implicitHeight: 40
    icon: "notifications"
    iconSource: source
    iconSize: Math.max(0, Math.round(Math.min(width, height) - 2 * imageMargin))
    backgroundColor: Theme.input

    GroupCountBadge {
        count: tile.count
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -4
        anchors.bottomMargin: -4
    }
}
