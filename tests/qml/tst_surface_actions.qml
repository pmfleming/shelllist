pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "SurfaceActions"
    when: windowShown
    visible: true
    width: 700
    height: 400
    Component {
        id: rowComponent
        Ui.SurfaceActionRow {
            width: 600
            actions: [
                {id: "connect", label: "Connect", icon: "wifi", presentation: {group: "primary"}},
                {id: "share", label: "Share", icon: "share", presentation: {group: "toolbar"}},
                {id: "forget", label: "Forget", icon: "delete", presentation: {group: "toolbar"}}
            ]
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_singleRowAndOverflow() {
        const row = createTemporaryObject(rowComponent, testCase);
        verify(row);
        tryCompare(row, "shownSecondaryCount", 2);
        compare(row.buttons.length, 3);
        const primary = findChild(row, "detailAction:connect");
        const secondary = findChild(row, "detailAction:share");
        compare(primary.mapToItem(row, 0, primary.height / 2).y, secondary.mapToItem(row, 0, secondary.height / 2).y);
        verify(primary.x < secondary.x);
        verify(primary.height > secondary.height);
        compare(primary.tone, "accent");
        compare(secondary.tone, "normal");
        verify(!primary.iconOnly);
        row.width = 180;
        tryCompare(row, "shownSecondaryCount", 0);
        compare(row.buttons.length, 2);
        const more = findChild(row, "surfaceActionMore");
        verify(more.visible);
        verify(primary.width + more.width + row.gap <= row.width);
        tryVerify(() => more.mapToItem(row, 0, 0).x >= primary.width);
        mouseClick(more, more.width / 2, more.height / 2);
        tryCompare(row, "popupOpen", true);
        keyClick(Qt.Key_Escape);
        tryCompare(row, "popupOpen", false);
        row.width = 600;
        tryCompare(row, "shownSecondaryCount", 2);
    }
}
