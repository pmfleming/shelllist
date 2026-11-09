import QtQuick

// Keep the native window focused until the Escape that dismissed it is up.
// Inner editors, dialogs and back-navigation still handle their own Escape.
Item {
    id: scope
    property bool escapeDown: false
    property bool dismissalPending: false

    signal dismissalDeferred
    signal dismissalReady

    function requestDismissal(): void {
        if (dismissalPending)
            return;
        if (!escapeDown) {
            dismissalReady();
            return;
        }
        dismissalPending = true;
        // The host snapshots navigation before we take focus to swallow repeats.
        dismissalDeferred();
        forceActiveFocus(Qt.OtherFocusReason);
    }
    function reset(): void {
        escapeDown = false;
        dismissalPending = false;
    }
    onVisibleChanged: if (!visible) reset()
    Connections {
        target: scope.Window.window
        function onActiveChanged(): void {
            if (!scope.Window.window.active) {
                const dismiss = scope.dismissalPending;
                scope.reset();
                // Once focus is lost, key-up may go elsewhere. Finish an
                // already-authorized close instead of stranding a suspended UI.
                if (dismiss)
                    scope.dismissalReady();
            }
        }
    }
    Keys.onShortcutOverride: function(event) {
        if (event.key === Qt.Key_Escape && !event.isAutoRepeat)
            escapeDown = true;
        if (dismissalPending)
            event.accepted = true;
    }
    Keys.onPressed: function(event) {
        if (dismissalPending)
            event.accepted = true;
    }
    Keys.onReleased: function(event) {
        if (event.key !== Qt.Key_Escape || event.isAutoRepeat)
            return;
        const dismiss = dismissalPending;
        reset();
        if (dismiss) {
            event.accepted = true;
            dismissalReady();
        }
    }
}
