pragma ComponentBehavior: Bound
import QtQuick

// A browse cursor is separate from native editor focus. Only opted-in chooser
// surfaces use this boundary; dialogs and native popups keep their own keys.
FocusScope {
    id: navigation

    property Item contentItem: null
    property bool headerShortcutsEnabled: false
    readonly property list<Item> headerButtons: collectHeaderButtons(contentItem)
    property ChooserMemory viewMemory: null
    property bool pendingMemory: false
    property bool resumeEditor: false
    property bool applyingMemory: false
    property bool restorationAllowed: !viewMemory || (viewMemory.controller.uiActive && !viewMemory.controller.uiSuspending)
    property var sessionLocation: null
    property var lastLocation: ({})
    readonly property list<Item> targets: collectTargets(contentItem)
    property Item currentTarget: null
    property bool awaitingContent: false
    property Item editorTarget: null
    readonly property DetailFlickable currentPage: pageForTarget(currentTarget)
    readonly property Item focusedTarget: targetForFocus(Window.window ? Window.window.activeFocusItem : null)
    readonly property bool popupOpen: (currentTarget as DropDownList)?.popup.visible ?? false
    readonly property bool editing: editorTarget !== null && (activeFocus || popupOpen)
    readonly property bool browsing: browseCursor.activeFocus && !editing
    readonly property Item highlightedControl: currentTarget instanceof ActionControl || currentTarget instanceof IconTile || editable(currentTarget) ? currentTarget : null
    Binding {
        target: navigation.highlightedControl
        property: "browseFocused"
        value: navigation.browsing
        when: navigation.highlightedControl !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    signal nativeFocusChanged
    signal interactionRequested
    signal exitRequested
    signal resultContextChanged

    function locationState(): var {
        const field = currentTarget as TextField;
        const editor = currentTarget as TextEditor;
        const key = FocusLocations.key(currentTarget);
        return {target: key, editing: key.length > 0 && editable(currentTarget) && editorTarget === currentTarget,
            selection: field && key ? field.selectionState() : editor ? editor.selectionState() : null};
    }
    function rememberLocation(): void {
        if (applyingMemory || pendingMemory || !currentTarget)
            return;
        lastLocation = locationState();
        if (viewMemory)
            viewMemory.rememberPage(viewMemory.activeTab, lastLocation);
    }
    Connections {
        target: navigation.editorTarget as TextField
        function onSelectionChanged(): void { navigation.rememberLocation(); }
    }
    Connections {
        target: navigation.editorTarget as TextEditor
        function onSelectionChanged(): void { navigation.rememberLocation(); }
    }
    function cancelSessionRestore(): void {
        if (sessionLocation) {
            sessionLocation = null;
            pendingMemory = false;
        }
        resumeEditor = false;
    }
    function focusSessionLocation(location: var): void {
        cancelSessionRestore();
        sessionLocation = location || ({});
        pendingMemory = true;
        resumeEditor = !!sessionLocation.editing;
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        Qt.callLater(restoreLocation);
    }
    function restoreLocation(): void {
        if (!pendingMemory || (!sessionLocation && (!viewMemory || !viewMemory.current)))
            return;
        const saved = sessionLocation || viewMemory.pageState(viewMemory.activeTab);
        const target = FocusLocations.uniqueTarget(targets, saved.target);
        applyingMemory = true;
        editorTarget = null;
        selectContent();
        if (target) {
            currentTarget = target;
            awaitingContent = false;
        }
        // Incubated controls can exist before their page's first layout.
        pendingMemory = awaitingContent || (currentPage && currentTarget !== currentPage && currentPage.contentHeight <= 0);
        if (activeFocus && restorationAllowed) {
            browseCursor.forceActiveFocus(Qt.OtherFocusReason);
            if (!pendingMemory && resumeEditor && saved.editing && target && editable(currentTarget))
                enterEditor();
            const field = editorTarget as TextField;
            if (field && field.inputActiveFocus)
                field.restoreSelection(saved.selection);
            const editor = editorTarget as TextEditor;
            if (editor && editor.activeFocus)
                editor.restoreSelection(saved.selection);
            if (sessionLocation)
                revealTarget();
        }
        applyingMemory = false;
        if (!pendingMemory) {
            sessionLocation = null;
            resumeEditor = false;
        }
    }
    function suspendView(): void {
        cancelSessionRestore();
        if (popupOpen)
            (currentTarget as DropDownList).popup.close();
    }
    function focusRememberedContent(): void {
        cancelSessionRestore();
        if (!viewMemory || !viewMemory.enabled) {
            focusContent();
            return;
        }
        viewMemory.synchronize();
        pendingMemory = true;
        resumeEditor = true;
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        restoreLocation();
        revealTarget();
    }
    onCurrentTargetChanged: if (activeFocus)
        rememberLocation()
    onContentItemChanged: if (viewMemory && viewMemory.enabled && !focusedTarget) {
        pendingMemory = true;
        Qt.callLater(restoreLocation);
    }
    Connections {
        target: navigation.viewMemory
        function onEnabledChanged(): void {
            navigation.pendingMemory = navigation.viewMemory.enabled;
            navigation.resumeEditor = false;
        }
        function onContextChanging(changedResult: bool): void {
            navigation.cancelSessionRestore();
            if (changedResult && navigation.activeFocus && navigation.restorationAllowed)
                navigation.resultContextChanged();
        }
        function onContextRestored(): void {
            navigation.resumeEditor = false;
            navigation.pendingMemory = true;
            navigation.restoreLocation();
        }
    }

    function collectTargets(item: Item, includeHeaders: bool): var {
        if (!item || !item.visible || item instanceof DetailsTabBar || (!includeHeaders && item instanceof DetailsHeader))
            return [];
        // Composite inputs are one browsing stop, not their internal buttons.
        if (editable(item) || item instanceof ActionControl || item.activeFocusOnTab)
            return [item];
        let result = [];
        const page = item as DetailFlickable;
        const children = page ? page.navigationContent.children : item.children;
        for (const child of children)
            result = result.concat(collectTargets(child, includeHeaders));
        // Arrow/Page keys can scroll read-only pages; Tab prefers their controls.
        if (page)
            result.push(page);
        return result;
    }
    function targetForFocus(item: Item): Item {
        while (item && item !== navigation) {
            if (targets.indexOf(item) >= 0)
                return item;
            item = item.parent;
        }
        return null;
    }
    function editable(item: Item): bool {
        return item instanceof TextField || item instanceof TextEditor || item instanceof DropDownList || item instanceof SegmentedControl || item instanceof ValueSlider || item instanceof LabeledValueSlider || item instanceof ToggleRow || item instanceof ToggleSwitch;
    }
    function collectHeaderButtons(item: Item): var {
        if (!item || !item.visible)
            return [];
        if (item instanceof DetailsHeader)
            return collectTargets(item, true);
        let result = [];
        for (const child of item.children)
            result = result.concat(collectHeaderButtons(child));
        return result;
    }
    function triggerHeader(index: int): void {
        const button = headerButtons[index] as ActionControl;
        if (!headerShortcutsEnabled || popupOpen || !button || !button.visible || !button.enabled || !button.interactive)
            return;
        interactionRequested();
        cancelSessionRestore();
        pendingMemory = false;
        button.activate();
    }
    function cycleFocus(backwards: bool): void {
        interactionRequested();
        rememberLocation();
        cancelSessionRestore();
        pendingMemory = false;
        awaitingContent = false;
        const controls = targets.filter(item => item.enabled && !(item instanceof DetailFlickable));
        const stops = controls.length ? controls : targets.filter(item => item.enabled);
        const index = browsing || focusedTarget ? stops.indexOf(currentTarget) : -1;
        editorTarget = null;
        if (stops.length) {
            const next = index < 0 ? (backwards ? stops.length - 1 : 0) : (index + (backwards ? -1 : 1) + stops.length) % stops.length;
            currentTarget = stops[next];
        }
        browseCursor.forceActiveFocus(Qt.TabFocusReason);
        rememberLocation();
        revealTarget();
    }
    function selectContent(): void {
        currentTarget = targets.length > 0 ? targets[0] : null;
        awaitingContent = !currentTarget;
    }
    function focusContent(reset: bool): void {
        cancelSessionRestore();
        editorTarget = null;
        if (reset || targets.indexOf(currentTarget) < 0)
            selectContent();
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        if (viewMemory && viewMemory.enabled && reset) {
            viewMemory.synchronize();
            pendingMemory = true;
        }
        restoreLocation();
        rememberLocation();
        revealTarget();
    }
    function move(delta: int): void {
        awaitingContent = false;
        pendingMemory = false;
        if (targets.length === 0)
            return;
        if (scrollPage(delta * Theme.controlHeight))
            return;
        const index = targets.indexOf(currentTarget);
        currentTarget = targets[Math.max(0, Math.min(targets.length - 1, index + delta))];
        revealTarget();
    }
    function scrollPage(distance: real): bool {
        const page = currentTarget as DetailFlickable;
        if (!page)
            return false;
        const next = Math.max(0, Math.min(Math.max(0, page.contentHeight - page.height), page.contentY + distance));
        if (next === page.contentY)
            return false;
        page.contentY = next;
        return true;
    }
    function pageForTarget(item: Item): DetailFlickable {
        while (item && !(item instanceof DetailFlickable))
            item = item.parent;
        return item as DetailFlickable;
    }
    Connections {
        target: navigation.currentPage
        function onMovementStarted(): void { navigation.interactionRequested(); }
        function onContentHeightChanged(): void {
            if (navigation.pendingMemory)
                Qt.callLater(navigation.restoreLocation);
        }
    }
    function revealTarget(): void {
        if (!currentTarget)
            return;
        let ancestor = currentTarget.parent;
        while (ancestor) {
            const page = ancestor as DetailFlickable;
            const viewport = ancestor as SurfaceViewport;
            if (page)
                page.revealItem(currentTarget);
            if (viewport)
                viewport.revealItem(currentTarget);
            ancestor = ancestor.parent;
        }
    }
    function enterEditor(): void {
        awaitingContent = false;
        const item = currentTarget;
        if (!item || !item.enabled || item instanceof DetailFlickable)
            return;
        const field = item as TextField;
        const editor = item as TextEditor;
        const labeled = item as LabeledValueSlider;
        const action = item as ActionControl;
        const segments = item as SegmentedControl;
        if ((field && field.readOnly) || (editor && !editor.editingAllowed) || (action && !action.interactive) || (segments && !segments.interactive))
            return;
        editorTarget = item;
        if (field)
            field.focusInput(false);
        else if (labeled)
            labeled.focusInput();
        else
            item.forceActiveFocus(Qt.OtherFocusReason);
        rememberLocation();
    }
    function retreat(): void {
        if (popupOpen) {
            (currentTarget as DropDownList).popup.close();
        } else if (editing) {
            focusContent();
        } else {
            exitRequested();
        }
    }
    onFocusedTargetChanged: if (focusedTarget) {
        // A pointer/native editor interaction supersedes queued presentation
        // restoration just as explicit key navigation does.
        if (!applyingMemory) {
            cancelSessionRestore();
            pendingMemory = false;
        }
        currentTarget = focusedTarget;
        editorTarget = focusedTarget;
        awaitingContent = false;
        nativeFocusChanged();
        rememberLocation();
    }
    onActiveFocusChanged: if (!activeFocus && !popupOpen) {
        rememberLocation();
        cancelSessionRestore();
        editorTarget = null;
    }
    onTargetsChanged: {
        if (pendingMemory && (sessionLocation || (viewMemory && viewMemory.enabled))) {
            Qt.callLater(restoreLocation);
            return;
        }
        if (awaitingContent || targets.indexOf(currentTarget) < 0) {
            editorTarget = null;
            selectContent();
            // A removed editor must not strand focus in a destroyed loader.
            if (activeFocus)
                browseCursor.forceActiveFocus();
        }
    }

    Item {
        id: browseCursor
        anchors.fill: parent
        focus: true
        Accessible.role: Accessible.Grouping
        Accessible.name: navigation.currentTarget && navigation.currentTarget.Accessible.name ? navigation.currentTarget.Accessible.name : qsTr("Details content")
        Accessible.description: navigation.editable(navigation.currentTarget) ? qsTr("Enter to edit") : ""
        Keys.onPressed: function (event) {
            if (event.modifiers !== Qt.NoModifier)
                return;
            navigation.interactionRequested();
            navigation.cancelSessionRestore();
            if (event.key === Qt.Key_Up)
                navigation.move(-1);
            else if (event.key === Qt.Key_Down)
                navigation.move(1);
            else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
                navigation.scrollPage((event.key === Qt.Key_PageDown ? 1 : -1) * navigation.height);
            else if (event.key === Qt.Key_Right)
                navigation.enterEditor();
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Escape)
                navigation.exitRequested();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (!event.isAutoRepeat) {
                    const action = navigation.currentTarget as ActionControl;
                    if (action && !navigation.editable(action))
                        action.activate();
                    else if (event.key !== Qt.Key_Space)
                        navigation.enterEditor();
                }
            } else
                return;
            event.accepted = true;
        }
    }

    Repeater {
        model: 9
        delegate: Item {
            id: shortcutSlot
            required property int index
            Shortcut {
                sequence: "Alt+" + (shortcutSlot.index + 1)
                enabled: navigation.headerShortcutsEnabled && !navigation.popupOpen && shortcutSlot.index < navigation.headerButtons.length
                autoRepeat: false
                onActivated: navigation.triggerHeader(shortcutSlot.index)
            }
        }
    }

    // Parenting to the target keeps the highlight attached during scrolling and
    // layout changes. It neither changes hit geometry nor takes input/focus.
    FocusRing {
        parent: navigation.currentTarget || navigation
        active: !navigation.highlightedControl && (navigation.browsing || (navigation.editing && !navigation.focusedTarget))
        ringColor: Theme.accent
        cornerRadius: (navigation.currentTarget as Rectangle)?.radius ?? Theme.controlRadius
    }
}
