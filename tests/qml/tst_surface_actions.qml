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
    Component {
        id: headerComponent
        Ui.DetailsHeader {
            width: 350
            uiScale: 1.25
            compactSecondaryActions: true
            title: "Very long translated network / application / clipboard title ".repeat(6)
            subtitle: "Connected / Last seen: 21s ago ".repeat(8)
            icon: "wifi"
            actions: [
                {id: "connect", label: "Connect", icon: "wifi", presentation: {group: "primary"}},
                {id: "share", label: "Share", icon: "share", presentation: {group: "toolbar"}}
            ]
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_narrowHeaderKeepsCommandsSeparateFromElidedTitle() {
        const header = createTemporaryObject(headerComponent, testCase);
        verify(waitForRendering(header));
        const primary = findChild(header, "detailAction:connect");
        const secondary = findChild(header, "detailAction:share");
        const title = findChild(header, "detailTitle");
        verify(primary.width > secondary.width, "the primary remains visually distinct");
        verify(primary.width === primary.height && secondary.width === secondary.height, "commands keep circular footprints");
        const p = primary.mapToItem(header, 0, 0);
        const s = secondary.mapToItem(header, 0, 0);
        verify(title.truncated);
        verify(title.mapToItem(header, title.width, 0).x < p.x);
        verify(s.y >= p.y + primary.height);
        verify(p.x + primary.width <= header.width && s.x + secondary.width <= header.width);
        compare(primary.Accessible.name, "Connect");
        header.actions = [];
        tryCompare(header, "height", header.headerHeight);
    }
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
    Component {
        id: promptComponent
        Ui.PromptDialog {
            width: 650
            height: 380
            title: "Delete this synthetic item?"
            detail: "This cannot be undone."
            inputLabel: "Required confirmation"
            inputText: "example"
            actionsVisible: true
            acceptLabel: "Delete item"
            acceptTone: "danger"
            acceptEnabled: false
            property int accepts: 0
            property int rejects: 0
            onAccepted: accepts++
            onCancelled: rejects++
        }
    }
    function test_modalActionsKeepContainedNativeTraversal() {
        const prompt = createTemporaryObject(promptComponent, testCase);
        prompt.focusInput();
        const field = findChild(prompt, "fieldInput");
        const accept = findChild(prompt, "detailAction:accept");
        const reject = findChild(prompt, "detailAction:reject");
        tryVerify(() => field.activeFocus);
        keyClick(Qt.Key_Tab);
        tryCompare(reject, "activeFocus", true);
        keyClick(Qt.Key_Tab);
        tryVerify(() => field.activeFocus);
        prompt.acceptEnabled = true;
        keyClick(Qt.Key_Tab);
        tryCompare(accept, "activeFocus", true);
        compare(accept.Accessible.name, "Delete item");
        keyClick(Qt.Key_Return);
        compare(prompt.accepts, 1);
        keyClick(Qt.Key_Tab);
        tryCompare(reject, "activeFocus", true);
        keyClick(Qt.Key_Space);
        compare(prompt.rejects, 1);
        keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        tryCompare(accept, "activeFocus", true);
        compare(prompt.accepts, 1, "focus traversal must not submit");
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
    function test_directCommandsAdaptInOrder_data() {
        return [
            {tag: "expanded", scale: 1, compact: true},
            {tag: "fractional", scale: 1.25, compact: true},
            {tag: "hidpi", scale: 2, compact: true},
            {tag: "standard", scale: 1, compact: false}
        ];
    }
    function test_directCommandsAdaptInOrder(data) {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        const row = navigation.row;
        row.uiScale = data.scale;
        row.compactSecondaryActions = data.compact;
        navigation.actions = [
            {id: "play", label: "Play", accessKey: "P", presentation: {group: "primary"}},
            {id: "back", label: "Previous", accessKey: "B", presentation: {group: "toolbar"}},
            {id: "unavailable", label: "Unavailable", accessKey: "U", enabled: false, presentation: {group: "toolbar"}},
            {id: "forward", label: "Next", accessKey: "N", presentation: {group: "toolbar"}},
            {id: "disabled", label: "Disabled", accessKey: "D", enabled: false, presentation: {group: "toolbar"}}
        ];
        navigation.focusContent(true);
        const normal = row.nominalControlHeight;
        const minimum = row.minimumControlHeight;
        const gap = row.minimumGap;
        const primarySize = findChild(row, "detailAction:play").width;
        const stages = [
            {width: 4 * normal + 3 * row.gap, size: normal, gap: row.gap, count: 4},
            {width: 4 * normal + 3 * (gap + 1), size: normal, gap: gap + 1, count: 4},
            {width: 4 * (minimum + 1) + 3 * gap, size: minimum + 1, gap: gap, count: 4},
            {width: 4 * minimum + 3 * gap, size: minimum, gap: gap, count: 4},
            {width: 3 * minimum + 2 * gap, size: minimum, gap: gap, count: 3},
            {width: 2 * minimum + gap, size: minimum, gap: gap, count: 2},
            {width: minimum, size: minimum, gap: gap, count: 2}
        ];
        for (const stage of stages) {
            navigation.width = stage.width;
            tryCompare(row, "shownSecondaryCount", stage.count);
            compare(row.controlHeight, stage.size);
            compare(row.secondaryGap, stage.gap);
            compare(row.overflowActions.length, 0);
            verify(!findChild(row, "surfaceActionMore").visible);
            tryCompare(navigation.headerButtons, "length", stage.count + 1);
            compare(findChild(row, "detailAction:play").width, primarySize);
            for (const button of row.secondaryButtons) {
                compare(button.width, stage.size);
                compare(button.height, stage.size);
                compare(button.iconSize, Math.round(stage.size / 2));
                const position = button.mapToItem(row, 0, 0);
                verify(position.x >= 0 && position.x + button.width <= row.width);
                verify(position.y + button.height <= row.height);
                verify(!button.activeFocusOnTab);
            }
            const before = navigation.calls;
            keyClick(Qt.Key_N, Qt.AltModifier);
            compare(navigation.calls, before + 1);
            compare(navigation.lastAction, "forward");
            const back = findChild(row, "detailAction:back");
            mouseClick(back, back.width / 2, back.height / 2);
            compare(navigation.calls, before + 2);
            compare(navigation.lastAction, "back");
            const disabled = findChild(row, "detailAction:unavailable");
            if (disabled)
                mouseClick(disabled, disabled.width / 2, disabled.height / 2);
            keyClick(Qt.Key_U, Qt.AltModifier);
            compare(navigation.calls, before + 2, "disabled or omitted commands never activate");
        }
        compare(row.secondaryRows, 2, "enabled commands wrap only after spacing, sizing and disabled omission");
        navigation.width = 4 * normal + 3 * row.gap;
        tryCompare(row, "shownSecondaryCount", 4, 5000, "widening restores disabled commands and normal geometry");
        compare(row.controlHeight, normal);
        compare(row.secondaryGap, row.gap);
        navigation.width = 2 * minimum + gap;
        tryCompare(row, "shownSecondaryCount", 2);
        navigation.actions = navigation.actions.map(action => Object.assign({}, action, {enabled: true}));
        tryCompare(row, "shownSecondaryCount", 4, 5000, "newly enabled commands reappear without a width change");
        tryCompare(navigation.headerButtons, "length", 5);
        keyClick(Qt.Key_U, Qt.AltModifier);
        compare(navigation.lastAction, "unavailable");
    }
    function test_disabledOnlyAndEmptyRowsReleaseGeometry() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        const row = navigation.row;
        navigation.actions = [{id: "disabled", label: "Disabled", enabled: false, accessKey: "D", presentation: {group: "toolbar"}}];
        navigation.width = row.nominalControlHeight;
        tryCompare(row, "shownSecondaryCount", 1);
        compare(row.height, row.nominalControlHeight);
        navigation.width = row.minimumControlHeight - 1;
        tryCompare(row, "shownSecondaryCount", 0);
        compare(row.height, 0);
        tryCompare(navigation.headerButtons, "length", 0);
        navigation.width = row.nominalControlHeight;
        tryCompare(row, "shownSecondaryCount", 1);
        compare(row.height, row.nominalControlHeight);
        row.secondaryVisible = false;
        tryCompare(row, "height", 0);
        navigation.actions = [];
        row.secondaryVisible = true;
        compare(row.height, 0);
        tryCompare(navigation.headerButtons, "length", 0);
    }
    function test_explicitOverflowReservesMoreAndRetainsGuards() {
        const navigation = createTemporaryObject(navigationComponent, testCase);
        navigation.actions = [
            {id: "play", label: "Play", accessKey: "P", presentation: {group: "primary"}},
            {id: "back", label: "Back", accessKey: "B", presentation: {group: "toolbar"}},
            {id: "forward", label: "Forward", accessKey: "F", presentation: {group: "toolbar"}},
            {id: "disabled", label: "Unavailable", enabled: false, presentation: {group: "overflow"}},
            {id: "next", label: "Next episode", accessKey: "N", presentation: {group: "overflow"}}
        ];
        navigation.focusContent(true);
        tryCompare(navigation.row, "shownSecondaryCount", 2);
        compare(navigation.row.overflowActions.length, 2, "explicit extras stay in More even with plenty of room");
        tryCompare(navigation.headerButtons, "length", 4);
        keyClick(Qt.Key_N, Qt.AltModifier);
        compare(navigation.calls, 0, "menu-only commands do not register hidden header chords");
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        keyClick(Qt.Key_Return);
        compare(navigation.lastAction, "next", "opening skips disabled overflow action");
        navigation.width = 72;
        tryCompare(navigation.row, "shownSecondaryCount", 2, 5000, "enabled toolbar commands stay direct even beside More");
        compare(navigation.row.overflowActions.length, 2);
        compare(navigation.row.secondaryRows, 2);
        navigation.actions = [{id: "only", label: "Only in More", presentation: {group: "overflow"}}];
        tryCompare(navigation.headerButtons, "length", 1);
        verify(navigation.row.height > 0, "overflow-only rows still have geometry");
        navigation.row.secondaryVisible = false;
        tryCompare(navigation.headerButtons, "length", 0);
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
