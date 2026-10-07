import QtQuick
import QtTest
import Quickshell
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "NotificationIcons"
    width: 100
    height: 100
    visible: true
    when: windowShown
    Component {
        id: iconComponent
        Ui.IconTile {
            required property var notification
            readonly property string source: Ui.NotificationIconSource.resolve(notification)
            iconSource: source
            icon: "notifications"
            width: 40; height: 40
        }
    }
    function cleanup() { Quickshell.themeIcons = ({}); }
    function test_centerPreviewRetainsSenderArtwork_data() {
        return [
            {tag: "signal-image-hint", name: "Signal", desktop: "", image: "org.signal.Signal", installed: "org.signal.Signal"},
            {tag: "absolute-image-path", name: "satty", desktop: "com.gabm.satty", image: Qt.resolvedUrl("fixtures/media-cover.svg").toString(), installed: ""}
        ];
    }
    function test_centerPreviewRetainsSenderArtwork(data) {
        const source = Qt.resolvedUrl("fixtures/media-cover.svg").toString();
        Quickshell.themeIcons = data.installed ? {[data.installed]: source} : ({});
        const preview = {id: 1, created_unix_ms: 1000, app_key: "test", app_name: data.name,
            app_icon: "", hints: {desktop_entry: data.desktop, image_path: data.image}, summary: "Test", body: ""};
        const icon = createTemporaryObject(iconComponent, testCase, {notification: preview});
        compare(icon.source, source, "compact previews use sender hints just like full messages/toasts");
        tryCompare(icon, "hasImage", true);
        const pixels = grabImage(icon);
        compare(pixels.pixel(12, 12), Qt.color("#197d87"), "the supplied artwork is painted, not the fallback bell");
    }
    function test_symbolicThemeFallbackPreservesSenderPriority() {
        const source = Qt.resolvedUrl("fixtures/media-cover.svg").toString();
        const other = "image://icon/exact";
        Quickshell.themeIcons = {"battery-caution-symbolic": source, "dialog-error-symbolic": source, "some-app": other};
        const warning = {app_icon: "battery-caution", app_name: "some-app"};
        compare(Ui.NotificationIconSource.resolve(warning), source, "symbolic sender artwork precedes an app-name guess");
        compare(Ui.NotificationIconSource.resolve({hints: {image_path: "dialog-error"}}), source);
        compare(Ui.NotificationIconSource.resolve({app_icon: "battery-caution-symbolic"}), source);
        Quickshell.themeIcons = {"battery-caution": other, "battery-caution-symbolic": source};
        compare(Ui.NotificationIconSource.resolve(warning), other, "prefer an installed exact icon over its symbolic variant");
    }
    function test_installedAppFallbackAndFailedFileRecover() {
        const source = Qt.resolvedUrl("fixtures/media-cover.svg").toString();
        Quickshell.themeIcons = {signal: source};
        const icon = createTemporaryObject(iconComponent, testCase, {notification: {app_name: "Signal", app_icon: "missing-icon"}});
        compare(icon.source, source);
        tryCompare(icon, "hasImage", true);
        icon.notification = {app_name: "No app", app_icon: "/nonexistent/shelllist-notification-icon.png"};
        tryCompare(icon, "hasImage", false);
        compare(icon.icon, "notifications", "failed local files retain the shared glyph fallback");
        icon.notification = {hints: {desktop_entry: "signal"}};
        compare(icon.source, source);
        tryCompare(icon, "hasImage", true);
    }
}
