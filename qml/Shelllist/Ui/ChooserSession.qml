import QtQuick

// Invocation focus is distinct from per-result presentation. Requests are
// consumed once per activation; explicit navigation cancels deferred work.
Item {
    id: session
    required property ChooserController controller
    property ChooserListPane listItem: null
    required property DetailsNavigation navigation
    property bool navigationAllowed: true
    property bool ready: true
    property string context: ""
    property bool consumed: false
    property bool pending: false
    property bool restoring: false
    property string lastRegion: "search"
    property string lastContext: ""
    readonly property bool invocationActive: enabled && controller.uiActive && !controller.uiSuspending
    readonly property string region: listItem && listItem.searchFocused ? "search" : listItem && listItem.listFocused ? "results" : listItem && listItem.controlLocation ? "list-control" : navigation.activeFocus || navigation.popupOpen ? "details" : insideList(Window.window ? Window.window.activeFocusItem : null) ? "search" : ""
    readonly property string selectedKey: controller.resultKeyAt(controller.selectionModel ? controller.selectionModel.selectedIndex : 0)

    function insideList(item: Item): bool {
        while (item && item !== listItem)
            item = item.parent;
        return listItem !== null && item === listItem;
    }
    function rememberRegion(): bool {
        if (!invocationActive || !navigationAllowed || !region)
            return false;
        lastRegion = region;
        lastContext = context;
        return true;
    }
    function capture(): void {
        if (!enabled || !controller.uiActive || !listItem)
            return;
        const fallback = lastRegion !== "details" || lastContext === context ? lastRegion : (controller.hasSelection ? "results" : "search");
        const currentRegion = region || fallback;
        const previous = controller.focusMemory;
        const waitingLocation = pending && previous.region === "details" && previous.context === context ? previous.location : null;
        const location = waitingLocation || navigation.sessionLocation || (navigation.activeFocus || navigation.popupOpen ? navigation.locationState() : navigation.lastLocation);
        controller.focusMemory = {region: currentRegion, context: context, selectedKey: selectedKey,
            list: listItem.sessionState(), location: currentRegion === "details" ? location : null};
    }
    function cancel(): void {
        pending = false;
        consumed = true;
        navigation.cancelSessionRestore();
    }
    function request(): void {
        if (consumed || !invocationActive)
            return;
        consumed = true;
        pending = navigationAllowed;
        if (pending)
            Qt.callLater(apply);
    }
    function apply(): void {
        if (!pending || !listItem)
            return;
        if (!invocationActive || !navigationAllowed) {
            pending = false;
            return;
        }
        controller.viewMemory.synchronize();
        const saved = controller.focusMemory;
        restoring = true;
        listItem.restoreSession(saved.list ? {selection: saved.list.selection,
            viewport: saved.selectedKey === selectedKey ? saved.list.viewport : null} : null);
        const details = saved.region === "details" && saved.context === context && controller.detailsOpen;
        pending = details && !ready;
        if (details) {
            // Browse while refresh validates capabilities; newer navigation
            // still cancels the pending editor resume.
            navigation.focusSessionLocation(pending ? Object.assign({}, saved.location || ({}), {editing: false}) : saved.location);
        } else if (saved.region === "results" || (saved.region === "details" && controller.hasSelection)) {
            listItem.focusList();
        } else if (saved.region !== "list-control" || !listItem.restoreControl(saved.list ? saved.list.control : null)) {
            listItem.focusSearch();
        }
        rememberRegion();
        restoring = false;
    }
    function modalFallback(generation: int): void {
        if (generation === controller.uiGeneration && invocationActive && navigationAllowed && !region && listItem)
            listItem.focusSearch();
    }
    // Disabling memory also retires queued work; re-enabling is not a new
    // invocation and must not resume a previously cancelled editor request.
    onEnabledChanged: if (!enabled) cancel()
    // Track restored focus too, so subsequent native focus loss retains it.
    onRegionChanged: if (rememberRegion() && !restoring && (pending || (region !== "details" && navigation.sessionLocation)))
        cancel()
    onContextChanged: {
        rememberRegion();
        if (navigation.sessionLocation && controller.focusMemory.context !== context)
            navigation.cancelSessionRestore();
    }
    function queueApply(): void {
        if (pending)
            Qt.callLater(apply);
    }
    // Let domain field reconciliation queued by the response finish first.
    onReadyChanged: if (ready && pending)
        Qt.callLater(queueApply)
    onListItemChanged: if (pending)
        Qt.callLater(apply)
    onNavigationAllowedChanged: {
        if (!navigationAllowed) {
            if (!controller.uiSuspending)
                capture();
            cancel();
        } else {
            Qt.callLater(modalFallback, controller.uiGeneration);
        }
    }
    Connections {
        target: session.listItem
        function onQuerySelectionChanged(): void {
            if (session.pending && !session.restoring && session.listItem.searchFocused)
                session.cancel();
        }
    }
    Connections {
        target: session.navigation
        function onInteractionRequested(): void { session.cancel(); }
        function onPopupOpenChanged(): void {
            if (session.navigation.popupOpen && !session.restoring && (session.pending || session.navigation.sessionLocation))
                session.cancel();
        }
        function onNativeFocusChanged(): void {
            if (!session.restoring && !session.navigation.applyingMemory && (session.pending || session.navigation.sessionLocation))
                session.cancel();
        }
    }
    Connections {
        target: session.navigation.editorTarget as TextField
        function onEdited(): void { session.cancel(); }
        function onCursorPositionChanged(): void {
            if (session.pending && !session.restoring && !session.navigation.applyingMemory && (session.navigation.editorTarget as TextField)?.inputActiveFocus)
                session.cancel();
        }
    }
    Connections {
        target: session.controller
        function onNavigationInteracted(): void { session.cancel(); }
        function onRestoreSessionFocusRequested(): void { session.request(); }
        function onUiSuspensionRequested(): void {
            if (session.navigationAllowed)
                session.capture();
            session.cancel();
            session.navigation.suspendView();
        }
        function onUiActiveChanged(): void {
            session.pending = false;
            session.consumed = false;
            if (!session.controller.uiActive)
                session.navigation.cancelSessionRestore();
            else
                session.rememberRegion();
        }
    }
}
