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
    function test_scaledLongLabelsAndSecondaryOnly_data() {
        return [{tag: "compact", width: 280, scale: 1}, {tag: "scaled", width: 420, scale: 1.5}, {tag: "wide", width: 650, scale: 1}];
    }
    function test_scaledLongLabelsAndSecondaryOnly(data) {
        const row = createTemporaryObject(rowComponent, testCase, {width: data.width, uiScale: data.scale});
        row.actions = [
            {id: "long", label: "Preview exceptionally long translated changes", icon: "preview", accessKey: "P", presentation: {group: "primary"}},
            {id: "other", label: "Another exceptionally long translated action", accessKey: "O", presentation: {group: "toolbar"}},
            {id: "delete", label: "Delete", icon: "delete", accessKey: "D", presentation: {group: "toolbar", tone: "danger"}}
        ];
        const primary = findChild(row, "detailAction:long");
        verify(primary);
        compare(primary.Accessible.name, row.actions[0].label);
        compare(primary.height, Math.round(Ui.Theme.primaryActionHeight * data.scale));
        tryVerify(() => row.buttons.every(button => button.mapToItem(row, 0, 0).x >= 0 && button.mapToItem(row, button.width, 0).x <= row.width));
        for (const button of row.buttons) {
            verify(button.height >= Ui.Theme.secondaryActionHeight);
            verify(Math.abs(button.mapToItem(row, 0, button.height / 2).y - row.height / 2) <= 0.5, "centres match within pixel rounding");
        }
        row.actions = [{id: "delete", label: "Delete", icon: "delete", accessKey: "D", presentation: {group: "toolbar", tone: "danger"}}];
        tryCompare(row.buttons, "length", 1);
        compare(row.buttons[0].tone, "danger");
        row.actions = [];
        tryCompare(row, "height", 0);
        compare(row.buttons.length, 0);
    }
    function test_overflowKeyboardSelectionAndFocusRestoration() {
        const navigation = createTemporaryObject(navigationComponent, testCase, {width: 160});
        navigation.actions = [
            {id: "connect", label: "Connect", accessKey: "C", presentation: {group: "primary"}},
            {id: "disabled", label: "Disabled", enabled: false, accessKey: "D", presentation: {group: "toolbar"}},
            {id: "first", label: "First", accessKey: "F", presentation: {group: "toolbar"}},
            {id: "other", label: "Other", accessKey: "O", presentation: {group: "toolbar"}}
        ];
        navigation.focusContent(true);
        tryVerify(() => navigation.headerButtons.some(button => button.surfaceShortcut === "Alt+M"));
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        const menu = findChild(navigation, "surfaceActionMenu");
        tryVerify(() => menu.activeFocus);
        compare(menu.currentIndex, 1, "opening skips disabled commands");
        keyClick(Qt.Key_Up);
        compare(menu.currentIndex, 2, "navigation wraps and skips disabled commands");
        keyClick(Qt.Key_Return);
        tryCompare(navigation, "popupOpen", false);
        compare(navigation.lastAction, "other");
        compare(navigation.calls, 1);
        verify(navigation.browsing, "closing restores preceding browse focus");
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        navigation.headerShortcutsEnabled = false;
        tryCompare(navigation, "popupOpen", false);
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1, "deactivated headers cannot dispatch");
    }
    function test_keysSurviveReorderAndStateChanges() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        navigation.focusContent(true);
        navigation.actions = [
            {id: "one", label: "One", accessKey: "F", presentation: {group: "toolbar"}},
            {id: "two", label: "Two", accessKey: "O", presentation: {group: "toolbar"}},
            {id: "reserved", label: "Reserved", accessKey: "S", presentation: {group: "toolbar"}},
            {id: "invalid", label: "Invalid", accessKey: "2", presentation: {group: "toolbar"}}
        ];
        tryCompare(navigation.headerButtons, "length", 4);
        compare(navigation.headerButtons[2].surfaceShortcut, "");
        compare(navigation.headerButtons[3].surfaceShortcut, "");
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(navigation.lastAction, "two");
        navigation.actions = navigation.actions.slice().reverse();
        tryVerify(() => navigation.headerButtons[3].surfaceShortcut === "Alt+F");
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(navigation.calls, 2);
        compare(navigation.lastAction, "two");
        navigation.actions = [{id: "disconnect", label: "Disconnect", accessKey: "D", presentation: {group: "primary"}}];
        tryCompare(navigation.headerButtons, "length", 1);
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(navigation.calls, 2);
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(navigation.lastAction, "disconnect");
        compare(navigation.calls, 3);
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
