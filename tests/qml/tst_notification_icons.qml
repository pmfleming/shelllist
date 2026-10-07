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
    function test_missingThemeIconsUseNeutralGlyph() {
        const icon = createTemporaryObject(iconComponent, testCase, {notification: {app_name: "Missing app", app_icon: "not-installed"}});
        compare(icon.source, "");
        compare(icon.icon, "notifications");
        verify(!icon.hasImage);
        verify(waitForRendering(icon));
        const image = grabImage(icon);
        verify(image.width > 0 && image.height > 0);
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
