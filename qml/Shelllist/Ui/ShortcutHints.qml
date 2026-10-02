pragma ComponentBehavior: Bound
import QtQuick

// Observe modifier keys before the native editor handles them, without consuming
// any event. Forwarding belongs only to the focused item in this live surface;
// Binding restores its original value when focus/surface ownership changes.
Item {
    id: hints
    required property Item scope
    required property DetailsNavigation navigation
    property bool tabsEnabled: false
    readonly property Item focusedItem: Window.window ? Window.window.activeFocusItem : null
    readonly property bool listening: enabled && visible && !!Window.window && Window.window.active && ownsFocus(focusedItem)
    property Item observedItem: null
    readonly property var observedKeys: observedItem ? observedItem.Keys : null
    property list<Item> forwardingTargets: []
    property bool altDown: false
    property bool ctrlDown: false
    property bool shiftDown: false
    property bool altReady: false
    property bool ctrlReady: false
    readonly property bool showActions: listening && altReady && altDown && !ctrlDown && navigation.headerShortcutsEnabled && !navigation.popupOpen
    readonly property bool showTabs: listening && ctrlReady && ctrlDown && !altDown && tabsEnabled && !navigation.popupOpen
    readonly property list<Item> tabBars: collectTabBars(scope)

    function ownsFocus(item: Item): bool {
        while (item) {
            if (item === scope)
                return true;
            item = item.parent;
        }
        return false;
    }
    function collectTabBars(item: Item): var {
        if (!item || !item.visible || item === hints || item instanceof DetailsHeader || item instanceof ActionControl)
            return [];
        if (item instanceof DetailsTabBar)
            return [item];
        let result = [];
        for (const child of item.children)
            result = result.concat(collectTabBars(child));
        return result;
    }
    function observeFocus(): void {
        const next = listening ? focusedItem : null;
        if (observedItem === next)
            return;
        // Detach first so Binding restores the old item's forwarding/binding.
        observedItem = null;
        if (!next)
            return;
        const targets = [hints];
        for (const item of next.Keys.forwardTo)
            if (item !== hints)
                targets.push(item);
        forwardingTargets = targets;
        observedItem = next;
    }
    function reset(): void {
        altDelay.stop();
        ctrlDelay.stop();
        altDown = false;
        ctrlDown = false;
        shiftDown = false;
        altReady = false;
        ctrlReady = false;
    }
    onFocusedItemChanged: observeFocus()
    onListeningChanged: {
        if (!listening)
            reset();
        observeFocus();
    }
    Component.onCompleted: observeFocus()
    Connections {
        target: hints.navigation
        function onPopupOpenChanged(): void { if (hints.navigation.popupOpen) hints.reset(); }
    }
    Binding {
        target: hints.observedKeys
        property: "forwardTo"
        value: hints.forwardingTargets
        when: hints.observedKeys !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    Keys.onPressed: function (event) {
        event.accepted = false;
        if (!listening || event.isAutoRepeat)
            return;
        if (event.key === Qt.Key_AltGr || event.key === Qt.Key_Meta) {
            reset();
            return;
        }
        if (event.key === Qt.Key_Alt && !altDown) {
            altDown = true;
            altDelay.restart();
        } else if (event.key === Qt.Key_Control && !ctrlDown) {
            ctrlDown = true;
            ctrlDelay.restart();
        } else if (event.key === Qt.Key_Shift) {
            shiftDown = true;
        }
        // Never show access-key hints for an AltGr-style Ctrl+Alt chord.
        if (altDown && ctrlDown) {
            altDelay.stop();
            ctrlDelay.stop();
            altReady = false;
            ctrlReady = false;
        }
    }
    Keys.onReleased: function (event) {
        event.accepted = false;
        if (event.isAutoRepeat)
            return;
        if (event.key === Qt.Key_Alt) {
            altDown = false;
            altReady = false;
            altDelay.stop();
        } else if (event.key === Qt.Key_Control) {
            ctrlDown = false;
            ctrlReady = false;
            ctrlDelay.stop();
        } else if (event.key === Qt.Key_Shift) {
            shiftDown = false;
        }
    }
    Timer { id: altDelay; interval: 250; onTriggered: hints.altReady = hints.altDown && !hints.ctrlDown }
    Timer { id: ctrlDelay; interval: 250; onTriggered: hints.ctrlReady = hints.ctrlDown && !hints.altDown }

    // Use the actual activation list and resolved shortcut, never positional keys.
    Repeater {
        model: hints.navigation.headerButtons
        delegate: Item {
            id: actionSlot
            required property Item modelData
            required property int index
            ShortcutBadge {
                parent: actionSlot.modelData || hints
                objectName: "headerShortcutBadge"
                anchors.top: parent ? parent.top : undefined
                anchors.right: parent ? parent.right : undefined
                anchors.topMargin: -4
                anchors.rightMargin: -4
                text: (actionSlot.modelData as ActionButton)?.surfaceShortcut.replace("Alt+", "") ?? ""
                visible: hints.showActions && text.length > 0 && !!actionSlot.modelData
            }
        }
    }
    Repeater {
        model: hints.tabBars
        delegate: Item {
            id: tabSlot
            required property Item modelData
            ShortcutBadge {
                parent: tabSlot.modelData || hints
                objectName: "tabShortcutBadge"
                anchors.top: parent ? parent.top : undefined
                anchors.right: parent ? parent.right : undefined
                text: hints.shiftDown ? "Ctrl+Shift+Tab" : "Ctrl+Tab"
                visible: hints.showTabs && !!tabSlot.modelData
            }
        }
    }
}
