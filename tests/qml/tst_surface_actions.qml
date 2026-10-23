pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Ui as Ui
import Shelllist.Core as Core

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
    function test_explicitControlChordSharesRegistryAndDuplicateGuards() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        const action = function(id, modifier) {
            return Core.Model.keepOpenAction(id, id, {accessKey: "N", accessModifier: modifier,
                presentation: {group: "toolbar"}});
        };
        navigation.actions = [action("alt", "Alt"), action("control", "Ctrl")];
        navigation.focusContent(true);
        tryVerify(() => navigation.headerButtons.some(button => button.surfaceShortcut === "Ctrl+N"));
        keyClick(Qt.Key_N, Qt.ControlModifier);
        compare(navigation.lastAction, "control");
        keyClick(Qt.Key_N, Qt.AltModifier);
        compare(navigation.lastAction, "alt");
        compare(navigation.calls, 2);
        navigation.actions = navigation.actions.concat([action("duplicate", "Ctrl")]);
        tryVerify(() => navigation.headerButtons.filter(button => button.accessModifier === "Ctrl")
            .every(button => button.surfaceShortcut === ""));
        keyClick(Qt.Key_N, Qt.ControlModifier);
        compare(navigation.calls, 2, "duplicate chords fail closed, not duplicate letters on different modifiers");
        keyClick(Qt.Key_N, Qt.AltModifier);
        compare(navigation.calls, 3);
        navigation.headerShortcutsEnabled = false;
        keyClick(Qt.Key_N, Qt.AltModifier);
        keyClick(Qt.Key_N, Qt.ControlModifier);
        compare(navigation.calls, 3, "both modifiers respect the same host guard");
    }
    function test_overlappingHostsShareOneCommandRegistry() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        navigation.additionalCommandItem = navigation.row;
        navigation.focusContent(true);
        tryVerify(() => navigation.headerButtons.length === 2);
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 1);
        navigation.row.headerCommands = false;
        tryVerify(() => navigation.headerButtons.length === 0 && navigation.contentCommands.length === 2);
        keyClick(Qt.Key_C, Qt.AltModifier);
        compare(navigation.calls, 2, "moving rows between registries cannot duplicate a shortcut");
        compare(navigation.availableFields().length, 0);
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
