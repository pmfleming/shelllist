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
                compactSecondaryActions: true
                actions: [
                    {id: "connect", label: "Connect", icon: "wifi", accessKey: "C", presentation: {group: "primary"}},
                    {id: "forget", label: "Forget", accessKey: "F", icon: "delete", presentation: {group: "toolbar"}}
                ]
                onTriggered: function(id) { navigation.calls++; navigation.lastAction = id; }
            }
        }
    }
    function init() { failOnWarning(/.*/); }
    Component {
        id: recoveryComponent
        Ui.DetailsNavigation {
            id: navigation
            width: 400
            height: 200
            contentItem: content
            headerShortcutsEnabled: true
            property int calls: 0
            Column {
                id: content
                width: parent.width
                Ui.TextField { objectName: "contextField"; width: parent.width; text: "Draft" }
                Ui.RecoveryActions {
                    objectName: "recoveryActions"
                    width: parent.width
                    onRetryRequested: navigation.calls++
                    onDiscardRequested: navigation.calls += 10
                }
            }
        }
    }
    function test_recoveryCommandsKeepIndependentGuardsAndPassiveLabels() {
        const navigation = createTemporaryObject(recoveryComponent, testCase);
        const actions = findChild(navigation, "recoveryActions");
        verify(waitForRendering(actions));
        mouseClick(actions.retryAction, 5, actions.retryAction.height / 2);
        compare(navigation.calls, 0, "the explanatory label is not a hit target");
        navigation.focusContent(true);
        keyClick(Qt.Key_Tab);
        compare(navigation.currentTarget.objectName, "contextField");
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(navigation.calls, 1);
        actions.retryAction.enabled = false;
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(navigation.calls, 1);
        keyClick(Qt.Key_X, Qt.AltModifier);
        compare(navigation.calls, 11, "retry pending must not disable independently allowed discard");
        actions.enabled = false;
        keyClick(Qt.Key_X, Qt.AltModifier);
        compare(navigation.calls, 11);
    }
    function test_letterActivationUsesDisplayedButtons() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
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
        navigation.actions = navigation.actions.map(action => Object.assign({}, action, {
            presentation: {group: action.id === "connect" ? "primary" : "overflow"}
        })).concat([{id: "share", label: "Share", icon: "share", accessKey: "H", presentation: {group: "overflow"}}]);
        navigation.width = 60;
        tryCompare(navigation.row, "shownSecondaryCount", 0);
        tryVerify(() => navigation.headerButtons[1].surfaceShortcut === "Alt+M");
        keyClick(Qt.Key_F, Qt.AltModifier);
        compare(navigation.calls, 1, "explicit menu actions have no header chord");
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
    function test_overflowKeyboardSelectionAndFocusRestoration() {
        const navigation = createTemporaryObject(navigationComponent, testCase, {width: 60});
        navigation.actions = [
            {id: "connect", label: "Connect", accessKey: "C", presentation: {group: "primary"}},
            {id: "disabled", label: "Disabled", enabled: false, accessKey: "D", presentation: {group: "overflow"}},
            {id: "first", label: "First", accessKey: "F", presentation: {group: "overflow"}},
            {id: "other", label: "Other", accessKey: "O", presentation: {group: "overflow"}}
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
        const actions = navigation.actions;
        const reorderOnClose = function () {
            if (!navigation.row.popupOpen) navigation.actions = actions.slice().reverse();
        };
        navigation.row.popupOpenChanged.connect(reorderOnClose);
        keyClick(Qt.Key_Return);
        tryCompare(navigation, "popupOpen", false);
        navigation.row.popupOpenChanged.disconnect(reorderOnClose);
        navigation.actions = actions;
        compare(navigation.lastAction, "other", "closing may reorder the model; activate the captured command");
        compare(navigation.calls, 1);
        verify(navigation.browsing, "closing restores preceding browse focus");
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        navigation.headerShortcutsEnabled = false;
        tryCompare(navigation, "popupOpen", false);
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1, "deactivated headers cannot dispatch");
    }
}
