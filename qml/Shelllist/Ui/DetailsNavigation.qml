pragma ComponentBehavior: Bound
import QtQuick

// Shared panel contract: result arrows, editable-only Tab and field transactions.
// See docs/chooser-keyboard-workflow.md. Required-input dialogs remain native.
FocusScope {
    id: navigation

    property Item contentItem: null
    property bool headerShortcutsEnabled: false
    property Item headerContentItem: contentItem
    readonly property var actionRows: collectActionRows(headerContentItem)
    readonly property list<Item> headerButtons: actionRows.reduce((buttons, row) => buttons.concat(row.buttons), [])
    readonly property list<Item> contentCommands: collectCommands(contentItem).filter(item => commandInScope(item))
    readonly property list<Item> commandButtons: headerButtons.concat(contentCommands.filter(item => !!(item as ActionControl)?.accessKey))
    readonly property bool commandMenuOpen: commandMenu.visible || actionRows.some(row => row.popupOpen)
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
    property bool finishingEditor: false
    readonly property DetailFlickable currentPage: pageForTarget(currentTarget)
    readonly property Item focusedTarget: targetForFocus(Window.window ? Window.window.activeFocusItem : null)
    readonly property bool popupOpen: ((currentTarget as DropDownList)?.popup.visible ?? false) || commandMenuOpen
    readonly property bool editing: editorTarget !== null && (activeFocus || popupOpen)
    readonly property bool browsing: browseCursor.activeFocus && !editing
    readonly property Item highlightedControl: editable(currentTarget) && (available(currentTarget) || editorTarget === currentTarget) ? currentTarget : null
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
    signal resultMoveRequested(int delta)

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
        finishEditor(false);
        selectContent();
        if (target && available(target)) {
            currentTarget = target;
            awaitingContent = false;
        }
        // Incubated controls can exist before their page's first layout.
        pendingMemory = awaitingContent || (currentPage && currentTarget !== currentPage && currentPage.contentHeight <= 0);
        if (activeFocus && restorationAllowed) {
            browseCursor.forceActiveFocus(Qt.OtherFocusReason);
            if (!pendingMemory && resumeEditor && saved.editing && target === currentTarget && editable(currentTarget) && !binary(currentTarget))
                enterEditor();
            const field = currentTarget as TextField;
            if (field && currentTarget === target)
                field.restoreSelection(saved.selection);
            const editor = currentTarget as TextEditor;
            if (editor && currentTarget === target)
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
        finishEditor(false);
        cancelSessionRestore();
        for (const row of actionRows) row.closePopup();
        commandMenu.close();
        const dropdown = currentTarget as DropDownList;
        if (dropdown && dropdown.popup.visible)
            dropdown.popup.close();
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
    onEnabledChanged: if (enabled) Qt.callLater(function () {
        if (navigation.awaitingContent) {
            navigation.selectContent();
            navigation.restoreLocation();
        }
    })
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
        if (!item || !item.visible || (item as DetailSection)?.informationOnly || item instanceof DetailsTabBar || item instanceof ModalFrame || (!includeHeaders && (item instanceof DetailsHeader || item instanceof SurfaceActionRow)))
            return [];
        // Composite inputs are one browsing stop, not their internal buttons.
        if (editable(item))
            return [item]; // Stable identity while capabilities/acknowledgements change.
        // Actions are Alt+letter commands, never field traversal stops.
        if (item instanceof ActionControl || item instanceof IconTile)
            return [];
        let result = [];
        const page = item as DetailFlickable;
        const children = page ? page.navigationContent.children : item.children;
        for (const child of children)
            result = result.concat(collectTargets(child, includeHeaders));
        // Page keys scroll read-only pages; Tab prefers editable controls.
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
    function available(item: Item): bool {
        return item && item.enabled && !((item as TextField)?.readOnly ?? false)
            && ((item as TextEditor)?.editingAllowed ?? true)
            && ((item as ActionControl)?.interactive ?? true)
            && ((item as SegmentedControl)?.interactive ?? true)
            && ((item as DropDownList)?.interactive ?? true);
    }
    function binary(item: Item): bool {
        return item instanceof ToggleRow || item instanceof ToggleSwitch;
    }
    function sessionFor(item: Item): FieldEditSession {
        return (item as TextField)?.editSession || (item as TextEditor)?.editSession
            || (item as DropDownList)?.editSession || (item as SegmentedControl)?.editSession
            || (item as ValueSlider)?.editSession || (item as LabeledValueSlider)?.editSession || null;
    }
    function finishEditor(save: bool): void {
        if (finishingEditor)
            return;
        finishingEditor = true;
        const target = editorTarget;
        const dropdown = target as DropDownList;
        if (dropdown && dropdown.popup.visible) {
            if (save) dropdown.stageIndex(dropdown.highlightedIndex);
            dropdown.popup.close();
        }
        const session = sessionFor(target);
        if (session) session.finish(save && available(target));
        editorTarget = null;
        finishingEditor = false;
    }
    function saveEditor(): void {
        if (!restorationAllowed) return;
        finishEditor(true);
        focusContent();
    }
    function collectActionRows(item: Item): var {
        if (!item || !item.visible || (item as DetailSection)?.informationOnly)
            return [];
        if (item instanceof SurfaceActionRow)
            return [item];
        let result = [];
        for (const child of item.children)
            result = result.concat(collectActionRows(child));
        return result;
    }
    function collectCommands(item: Item): var {
        if (!item || !item.visible || item instanceof SurfaceActionRow || item instanceof DetailsHeader || item instanceof DetailsTabBar || item instanceof ModalFrame)
            return [];
        const action = item as ActionControl;
        let result = action && !binary(action) ? [action] : [];
        for (const child of item.children)
            result = result.concat(collectCommands(child));
        return result;
    }
    function commandInScope(item: Item): bool {
        const scope = (item as ActionControl)?.commandScope;
        if (!scope) return true;
        let target = currentTarget;
        while (target) {
            if (target === scope) return true;
            target = target.parent;
        }
        return false;
    }
    function shortcutFor(item: Item): string {
        const button = item as ActionControl;
        if (!button || commandButtons.indexOf(button) < 0 || !/^[A-IK-RT-Z]$/.test(button.accessKey) || commandButtons.filter(other => (other as ActionControl)?.accessKey === button.accessKey).length !== 1)
            return "";
        return "Alt+" + button.accessKey;
    }
    onHeaderShortcutsEnabledChanged: if (!headerShortcutsEnabled) {
        commandMenu.close();
        for (const row of actionRows) row.closePopup();
    }
    function triggerHeader(index: int): void {
        const button = commandButtons[index] as ActionControl;
        if (!headerShortcutsEnabled || popupOpen || !button || !button.visible || !button.enabled || !button.interactive)
            return;
        interactionRequested();
        cancelSessionRestore();
        pendingMemory = false;
        button.activate();
    }
    function cycleFocus(backwards: bool): void {
        if (!restorationAllowed) return;
        interactionRequested();
        rememberLocation();
        cancelSessionRestore();
        pendingMemory = false;
        awaitingContent = false;
        const retainEditing = editing;
        const previous = currentTarget;
        finishEditor(true);
        const controls = targets.filter(item => available(item) && editable(item));
        const stops = controls.length ? controls : targets.filter(item => item.enabled && item instanceof DetailFlickable);
        const index = stops.indexOf(previous);
        if (stops.length) {
            const next = index < 0 ? (backwards ? stops.length - 1 : 0) : (index + (backwards ? -1 : 1) + stops.length) % stops.length;
            currentTarget = stops[next];
        } else {
            currentTarget = null;
        }
        browseCursor.forceActiveFocus(Qt.TabFocusReason);
        if (retainEditing && !binary(currentTarget))
            enterEditor();
        rememberLocation();
        revealTarget();
    }
    function selectContent(): void {
        currentTarget = targets.find(item => available(item) && editable(item)) || targets.find(item => item instanceof DetailFlickable && item.enabled) || null;
        awaitingContent = !currentTarget;
    }
    function focusContent(reset: bool): void {
        finishEditor(false);
        cancelSessionRestore();
        if (reset || targets.indexOf(currentTarget) < 0)
            selectContent();
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        if (viewMemory && viewMemory.enabled) {
            if (reset) viewMemory.synchronize();
            pendingMemory = true;
        }
        restoreLocation();
        rememberLocation();
        revealTarget();
    }
    function move(delta: int): void {
        awaitingContent = false;
        pendingMemory = false;
        resultMoveRequested(delta);
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
        if (!available(item) || !editable(item))
            return;
        if (binary(item)) {
            (item as ActionControl).activate();
            return;
        }
        const field = item as TextField;
        const labeled = item as LabeledValueSlider;
        editorTarget = item;
        const session = sessionFor(item);
        if (session) session.begin();
        if (field)
            field.focusInput(false);
        else if (labeled)
            labeled.focusInput();
        else
            item.forceActiveFocus(Qt.OtherFocusReason);
        rememberLocation();
    }
    function retreat(): void {
        if (commandMenuOpen) {
            commandMenu.close();
            for (const row of actionRows) row.closePopup();
        } else if (editing) {
            finishEditor(false);
            focusContent();
        } else if (popupOpen) {
            for (const row of actionRows) row.closePopup();
        } else {
            exitRequested();
        }
    }
    onFocusedTargetChanged: if (focusedTarget && !finishingEditor) {
        // A pointer/native editor interaction supersedes queued presentation
        // restoration just as explicit key navigation does.
        if (!applyingMemory) {
            cancelSessionRestore();
            pendingMemory = false;
        }
        if (editorTarget !== focusedTarget)
            finishEditor(false);
        currentTarget = focusedTarget;
        editorTarget = editable(focusedTarget) && !binary(focusedTarget) && (available(focusedTarget) || sessionFor(focusedTarget)?.active) ? focusedTarget : null;
        const session = sessionFor(editorTarget);
        if (session) session.begin();
        awaitingContent = false;
        nativeFocusChanged();
        rememberLocation();
    } else if (!focusedTarget && editorTarget && !popupOpen && !finishingEditor && activeFocus) {
        finishEditor(false);
    }
    onActiveFocusChanged: if (!activeFocus && !popupOpen && !finishingEditor) {
        rememberLocation();
        finishEditor(false);
        cancelSessionRestore();
    }
    onTargetsChanged: {
        if (pendingMemory && (sessionLocation || (viewMemory && viewMemory.enabled))) {
            Qt.callLater(restoreLocation);
            return;
        }
        if (!finishingEditor && (awaitingContent || targets.indexOf(currentTarget) < 0)) {
            finishEditor(false);
            selectContent();
            // A removed editor must not strand focus in a destroyed loader.
            if (activeFocus)
                browseCursor.forceActiveFocus();
        }
    }

    // Pointer-focused command buttons still belong to the detail region.
    Keys.onPressed: function (event) {
        if (editing || popupOpen || event.modifiers !== Qt.NoModifier)
            return;
        if (event.key === Qt.Key_Left)
            exitRequested();
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            move(event.key === Qt.Key_Up ? -1 : 1);
        else
            return;
        event.accepted = true;
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
                event.accepted = true; // Already expanded. Only Enter edits.
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Escape)
                navigation.exitRequested();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (!event.isAutoRepeat) {
                    if (event.key !== Qt.Key_Space)
                        navigation.enterEditor();
                }
            } else
                return;
            event.accepted = true;
        }
    }

    DetailsCommandMenu {
        id: commandMenu
        commands: navigation.contentCommands.filter(item => !(item as ActionControl)?.accessKey)
    }
    Shortcut {
        sequence: "Alt+J"
        enabled: navigation.headerShortcutsEnabled && !navigation.popupOpen && commandMenu.commands.length > 0
        autoRepeat: false
        onActivated: commandMenu.open()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: navigation.editing && navigation.restorationAllowed && !navigation.commandMenuOpen
        autoRepeat: false
        onActivated: navigation.saveEditor()
    }

    Repeater {
        model: navigation.commandButtons
        delegate: Item {
            id: shortcutSlot
            required property Item modelData
            required property int index
            readonly property string sequence: navigation.shortcutFor(modelData)
            Shortcut {
                sequence: shortcutSlot.sequence
                enabled: !!shortcutSlot.sequence && navigation.headerShortcutsEnabled && !navigation.popupOpen
                autoRepeat: false
                onActivated: navigation.triggerHeader(shortcutSlot.index)
            }
        }
    }

}
