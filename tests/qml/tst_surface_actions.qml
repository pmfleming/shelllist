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
            uiScale: 1
            title: "Very long translated network / application / clipboard title ".repeat(6)
            subtitle: "Connected / Last seen: 21s ago ".repeat(8)
            icon: "wifi"
            statusIndicatorVisible: true
            actions: [
                {id: "connect", label: "Connect", icon: "wifi", accessKey: "C", presentation: {group: "primary"}},
                {id: "forget", label: "Forget", icon: "delete", presentation: {group: "toolbar", tone: "danger"}},
                {id: "share", label: "Share", icon: "share", presentation: {group: "toolbar"}}
            ]
        }
    }
    function init() { failOnWarning(/.*/); }
    function test_commandNamesResolveToSymbols() {
        for (const icon of Ui.MaterialIcons.commandSymbols)
            compare(Ui.MaterialIcons.name(icon), icon, "semantic commands must not paint literal words");
        compare(Ui.MaterialIcons.name("Unknown application action"), "", "opaque app labels are not icons");
    }
    function test_headerGeometry_data() {
        return [
            {tag: "compact", width: 280, scale: 1},
            {tag: "normal", width: 480, scale: 1},
            {tag: "unexpanded", width: 480, scale: 1, compact: false},
            {tag: "fractional", width: 600, scale: 1.25},
            {tag: "hidpi", width: 680, scale: 2},
            {tag: "signal", width: 480, scale: 1, signal: true},
            {tag: "image", width: 480, scale: 1, image: true}
        ];
    }
    function test_headerGeometry(data) {
        const header = createTemporaryObject(headerComponent, testCase, {
            width: data.width, uiScale: data.scale, signalIcon: data.signal || false,
            compactSecondaryActions: data.compact !== false,
            iconSource: data.image ? Qt.resolvedUrl("../../qml/Shelllist/Activity/assets/weather/clear-day.svg") : ""
        });
        verify(header);
        verify(waitForRendering(header));
        const primary = findChild(header, "detailAction:connect");
        const secondary = findChild(header, "detailAction:share");
        const identity = findChild(header, "detailIdentityIcon");
        if (data.image) tryCompare(identity, "hasImage", true);
        const title = findChild(header, "detailTitle");
        const subtitle = findChild(header, "detailSubtitle");
        const p = primary.mapToItem(header, 0, 0);
        const s = secondary.mapToItem(header, 0, 0);
        const i = identity.mapToItem(header, 0, 0);
        const t = title.mapToItem(header, 0, 0);
        compare(p.x + primary.width, header.width);
        compare(s.x + secondary.width, header.width);
        compare(primary.width, primary.height);
        compare(secondary.width, secondary.height);
        compare(primary.width, Math.round(56 * data.scale));
        compare(primary.iconSize, Math.round(28 * data.scale));
        compare(secondary.width, Math.round((data.compact === false ? 48 : 32) * data.scale));
        compare(secondary.iconSize, Math.round((data.compact === false ? 24 : 16) * data.scale));
        compare(findChild(secondary, "actionLabel").iconSize, secondary.iconSize);
        verify(primary.width > secondary.width);
        verify(primary.iconSize > secondary.iconSize);
        fuzzyCompare(p.y + primary.height / 2, i.y + identity.height / 2, 0.5);
        fuzzyCompare(p.y + primary.height / 2, t.y + title.height / 2, 0.5);
        verify(s.y >= header.headerHeight + 8 * data.scale);
        verify(t.x + title.width + Ui.Theme.actionTitleGap * data.scale <= p.x + 0.5);
        verify(title.truncated && subtitle.truncated);
        verify(subtitle.mapToItem(header, 0, subtitle.height).y <= s.y);
        compare(findChild(primary, "actionLabel").label, "");
        compare(primary.Accessible.name, "Connect");
        compare(primary.radius, primary.width / 2);
        mousePress(primary, primary.width / 2, primary.height / 2);
        compare(primary.radius, primary.width / 2, "press feedback must remain circular");
        mouseRelease(primary, primary.width / 2, primary.height / 2);
        header.actions = header.actions.slice(1);
        tryCompare(primary, "visible", false);
        compare(header.height, header.headerHeight + 8 * data.scale + secondary.height);
        header.actions = [];
        tryCompare(header, "height", header.headerHeight);
    }
    Component {
        id: contextualComponent
        Ui.DetailsNavigation {
            id: navigation
            width: 400
            height: 200
            contentItem: content
            headerShortcutsEnabled: true
            property int calls: 0
            property bool recovery: false
            Column {
                id: content
                width: parent.width
                Ui.TextField { objectName: "contextField"; width: parent.width; text: "Draft" }
                Ui.LabeledAction {
                    objectName: "contextRetry"
                    visible: !navigation.recovery
                    width: parent.width
                    label: "Retry a failed save"
                    icon: "refresh"
                    accessKey: "R"
                    onClicked: navigation.calls++
                }
                Ui.RecoveryActions {
                    objectName: "recoveryActions"
                    visible: navigation.recovery
                    width: parent.width
                    onRetryRequested: navigation.calls++
                    onDiscardRequested: navigation.calls += 10
                }
            }
        }
    }
    function test_recoveryCommandsKeepIndependentGuardsAndSkipTab() {
        const navigation = createTemporaryObject(contextualComponent, testCase, {recovery: true});
        const actions = findChild(navigation, "recoveryActions");
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
    function test_contextualLabelsStayPassiveAndCommandsStayOutOfTab() {
        const navigation = createTemporaryObject(contextualComponent, testCase);
        const row = findChild(navigation, "contextRetry");
        const button = row.button;
        verify(waitForRendering(row));
        compare(button.width, button.height);
        mouseClick(row, 5, row.height / 2);
        compare(navigation.calls, 0, "passive label is not a stretched hit target");
        navigation.focusContent(true);
        compare(navigation.targets.length, 1);
        keyClick(Qt.Key_Tab);
        compare(navigation.currentTarget.objectName, "contextField");
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(navigation.calls, 1);
        mouseClick(button, button.width / 2, button.height / 2);
        compare(navigation.calls, 2);
        row.enabled = false;
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(navigation.calls, 2);
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
    function test_modalCircularActionsKeepContainedNativeTraversal() {
        const prompt = createTemporaryObject(promptComponent, testCase);
        prompt.focusInput();
        const field = findChild(prompt, "fieldInput");
        const accept = findChild(prompt, "detailAction:accept");
        const reject = findChild(prompt, "detailAction:reject");
        compare(reject.width, 48, "modal secondary circles must not shrink");
        compare(reject.iconSize, 24);
        tryVerify(() => field.activeFocus);
        keyClick(Qt.Key_Tab);
        tryCompare(reject, "activeFocus", true); // Disabled submit is skipped.
        keyClick(Qt.Key_Tab);
        tryVerify(() => field.activeFocus);
        prompt.acceptEnabled = true;
        keyClick(Qt.Key_Tab);
        tryCompare(accept, "activeFocus", true);
        compare(accept.Accessible.name, "Delete item");
        compare(accept.icon, "delete");
        compare(accept.width, accept.height);
        compare(findChild(accept, "actionLabel").label, "");
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
        navigation.actions = navigation.actions.concat([{id: "share", label: "Share", icon: "share", accessKey: "H", presentation: {group: "toolbar"}}]);
        navigation.width = 60;
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
    function test_overflowKeyboardSelectionAndFocusRestoration() {
        const navigation = createTemporaryObject(navigationComponent, testCase, {width: 60});
        navigation.actions = [
            {id: "connect", label: "Connect", accessKey: "C", presentation: {group: "primary"}},
            {id: "disabled", label: "Disabled", enabled: false, accessKey: "D", presentation: {group: "toolbar"}},
            {id: "first", label: "First", accessKey: "F", presentation: {group: "toolbar"}},
            {id: "other", label: "Other", accessKey: "O", presentation: {group: "toolbar"}}
        ];
        navigation.focusContent(true);
        tryVerify(() => navigation.headerButtons.some(button => button.surfaceShortcut === "Alt+M"));
        const more = findChild(navigation, "surfaceActionMore");
        compare(more.width, 32);
        compare(more.height, 32);
        compare(more.iconSize, 16);
        navigation.width = 120;
        tryCompare(navigation.row, "shownSecondaryCount", 3, 5000, "smaller circles fit without overflow");
        navigation.width = 60;
        tryCompare(navigation.row, "shownSecondaryCount", 0);
        keyClick(Qt.Key_M, Qt.AltModifier);
        tryCompare(navigation, "popupOpen", true);
        const menu = findChild(navigation, "surfaceActionMenu");
        tryVerify(() => menu.activeFocus);
        compare(menu.currentIndex, 1, "opening skips disabled commands");
        tryVerify(() => menu.currentItem !== null);
        compare(menu.currentItem.height, 48, "named overflow entries keep their full size");
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
