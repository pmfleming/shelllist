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
    Component {
        id: navigationComponent
        Ui.DetailsNavigation {
            id: navigation
            width: 600
            height: 200
            headerShortcutsEnabled: true
            contentItem: row
            property alias actions: row.actions
            property alias row: row
            property int calls: 0
            property string lastAction: ""
            Ui.SurfaceActionRow {
                id: row
                width: parent.width
                actions: [
                    {id: "connect", label: "Connect", accessKey: "C", presentation: {group: "primary"}},
                    {id: "forget", label: "Forget", accessKey: "F", icon: "delete", presentation: {group: "toolbar"}}
                ]
                onTriggered: function(id) { navigation.calls++; navigation.lastAction = id; }
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_letterActivationUsesDisplayedButtons() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        verify(navigation);
        navigation.focusContent(true);
        tryCompare(navigation.headerButtons, "length", 2);
        const primary = navigation.headerButtons[0];
        tryCompare(primary, "surfaceShortcut", "Alt+C");
        verify(primary.Accessible.description.includes("Alt+C"));
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1);
        compare(navigation.lastAction, "connect");
        keyClick(Qt.Key_1, Qt.AltModifier);
        keyClick(Qt.Key_C, Qt.ControlModifier | Qt.AltModifier);
        compare(navigation.calls, 1);
        navigation.headerButtons[1].enabled = false;
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(navigation.calls, 1);
        navigation.width = 150;
        tryCompare(navigation.row, "shownSecondaryCount", 0);
        tryVerify(() => navigation.headerButtons[1].surfaceShortcut === "Alt+M");
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(navigation.calls, 1, "overflowed actions have no header chord");
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        wait(50);
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1);
        keyClick(Qt.Key_Escape);
        tryCompare(navigation, "popupOpen", false);
        navigation.actions = [
            {id: "one", label: "One", accessKey: "C", presentation: {group: "primary"}},
            {id: "two", label: "Two", accessKey: "C", presentation: {group: "toolbar"}}
        ];
        navigation.width = 600;
        tryCompare(navigation.headerButtons, "length", 2);
        tryCompare(navigation.headerButtons[0], "surfaceShortcut", "");
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1, "duplicate letters fail closed");
    }
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
