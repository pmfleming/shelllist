pragma ComponentBehavior: Bound
import QtQuick

// Shared panel contract: result arrows, editable-only Tab and field transactions.
// See docs/chooser-keyboard-workflow.md. Required-input dialogs remain native.
FocusScope {
    id: navigation

    property Item contentItem: null
    // Selected-result commands may live beside the list, independent of details.
    property Item additionalCommandItem: null
    property bool headerShortcutsEnabled: false
    property Item headerContentItem: contentItem
    readonly property list<SurfaceActionRow> actionRows: uniqueItems(collectActionRows(headerContentItem).concat(collectActionRows(additionalCommandItem)))
    readonly property list<ActionControl> headerButtons: actionRows.reduce((buttons, row) => buttons.concat(Array.from(row.buttons)), [])
    readonly property list<ActionControl> contentCommands: uniqueItems(collectCommands(contentItem).concat(collectCommands(additionalCommandItem))).filter(item => commandInScope(item))
    readonly property list<ActionControl> commandButtons: headerButtons.concat(contentCommands.filter(item => !!item.accessKey))
    readonly property bool commandMenuOpen: commandMenu.visible || actionRows.some(row => row.popupOpen)
    property ChooserMemory viewMemory: null
    property bool pendingMemory: false
    property bool resumeEditor: false
    property bool applyingMemory: false
    property bool restorationAllowed: !viewMemory || (viewMemory.controller.uiActive && !viewMemory.controller.uiSuspending)
    property var sessionLocation: null
    property var lastLocation: ({})
    readonly property bool contentReady: contentItem !== null && loadersReady(contentItem)
    readonly property list<Item> targets: contentReady ? collectTargets(contentItem) : []
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
        const key = FocusLocations.key(currentTarget);
        return {target: key, editing: key.length > 0 && editable(currentTarget) && editorTarget === currentTarget,
            selection: key || currentTarget instanceof TextEditor ? FocusLocations.selection(currentTarget) : null};
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
        restoreFocus(target, saved);
        applyingMemory = false;
        if (!pendingMemory) {
            sessionLocation = null;
            resumeEditor = false;
        }
    }
    function restoreFocus(target: Item, saved: var): void {
        if (!activeFocus || !restorationAllowed)
            return;
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        if (target === currentTarget) {
            if (!pendingMemory && resumeEditor && saved.editing && sessionFor(target))
                enterEditor();
            FocusLocations.restoreSelection(target, saved.selection);
        }
        if (sessionLocation)
            revealTarget();
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

    // These subtrees own commands, modal focus or read-only information, not
    // fields. Use the same boundary for discovery and incubation readiness.
    function fieldBoundary(item: Item): bool {
        return item instanceof ActionControl || item instanceof IconTile
            || item instanceof CommandGroup || item instanceof ModalFrame
            || item instanceof DetailsHeader || item instanceof DetailsTabBar
            || item instanceof SurfaceActionRow || (item as DetailSection)?.informationOnly === true;
    }
    // Loader children become discoverable during incubation, before completion
    // handlers initialize fields. Do not consume saved focus/selection yet.
    function loadersReady(item: Item): bool {
        const parentLoader = item.parent as Loader;
        if (parentLoader && parentLoader.active && parentLoader.status !== Loader.Ready)
            return false;
        const loader = item as Loader;
        if (loader && loader.active && loader.status === Loader.Loading)
            return false;
        // Match target traversal boundaries; native input/cursor decorations
        // are not pages and may be created as a consequence of restoring focus.
        if (editable(item) || fieldBoundary(item))
            return true;
        const page = item as DetailFlickable;
        const children = page ? page.navigationContent.children : item.children;
        for (const child of children) {
            if (!loadersReady(child))
                return false;
        }
        return true;
    }
    function collectTargets(item: Item): var {
        if (!item || !item.visible)
            return [];
        // Composite inputs are one browsing stop, not their internal buttons.
        if (editable(item))
            return [item]; // Stable identity while capabilities/acknowledgements change.
        if (fieldBoundary(item))
            return [];
        let result = [];
        const page = item as DetailFlickable;
        const children = page ? page.navigationContent.children : item.children;
        for (const child of children)
            result = result.concat(collectTargets(child));
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
        return binary(item) || sessionFor(item) !== null;
    }
    function available(item: Item): bool {
        return sessionFor(item)?.available ?? (item !== null && item.enabled && ((item as ActionControl)?.interactive ?? true));
    }
    // Read current targets synchronously: onTargetsChanged can run before a
    // derived list binding updates during Loader creation/removal.
    function availableFields(): var {
        return targets.filter(item => editable(item) && available(item));
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
    function uniqueItems(items: var): var {
        return items.filter((item, index) => items.indexOf(item) === index);
    }
    function collectActionRows(item: Item): var {
        if (!item || !item.visible || item instanceof ModalFrame || (item as DetailSection)?.informationOnly)
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
    function commandInScope(item: ActionControl): bool {
        const scope = item.commandScope;
        if (!scope) return true;
        let target = currentTarget;
        while (target) {
            if (target === scope) return true;
            target = target.parent;
        }
        return false;
    }
    function shortcutFor(button: ActionControl): string {
        if (!button || commandButtons.indexOf(button) < 0 || !/^[A-IK-RT-Z]$/.test(button.accessKey) || commandButtons.filter(other => other.accessKey === button.accessKey).length !== 1)
            return "";
        return "Alt+" + button.accessKey;
    }
    onHeaderShortcutsEnabledChanged: if (!headerShortcutsEnabled) {
        commandMenu.close();
        for (const row of actionRows) row.closePopup();
    }
    function triggerHeader(index: int): void {
        const button = commandButtons[index];
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
        // Saving can disable, hide or remove the current field. Capture its
        // directional neighbours before the save; revalidate them afterwards.
        // Looking up the old field in the filtered post-save stops loses its
        // position and incorrectly restarts traversal at the first/last field.
        const order = targets.filter(item => editable(item));
        if (backwards) order.reverse();
        const start = order.indexOf(currentTarget) + 1;
        const candidates = order.slice(start).concat(order.slice(0, start));
        finishEditor(true);
        const fields = availableFields();
        const stops = fields.length ? fields : targets.filter(item => item.enabled && item instanceof DetailFlickable);
        currentTarget = candidates.find(item => fields.indexOf(item) >= 0)
            || stops[backwards ? stops.length - 1 : 0] || null;
        browseCursor.forceActiveFocus(Qt.TabFocusReason);
        if (retainEditing && !binary(currentTarget))
            enterEditor();
        rememberLocation();
        revealTarget();
    }
    function selectContent(): void {
        currentTarget = availableFields()[0] || targets.find(item => item instanceof DetailFlickable && item.enabled) || null;
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
        const session = sessionFor(focusedTarget);
        editorTarget = session && (session.available || session.active) ? focusedTarget : null;
        if (editorTarget) session.begin();
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

    function closeCommandMenu(): void { commandMenu.close(); }
    function openCommandMenu(): void { openCommandMenuFor(null); }
    // Contextual buttons use the same menu, modal guards and native traversal
    // as Alt+J, restricted to their command-only subtree when requested.
    function openCommandMenuFor(root: Item): void {
        if (!headerShortcutsEnabled || popupOpen)
            return;
        commandMenu.commandRoot = root;
        if (commandMenu.commands.length > 0)
            commandMenu.open();
    }
    ActionMenu {
        id: commandMenu
        parent: navigation.additionalCommandItem && navigation.additionalCommandItem.visible ? navigation.additionalCommandItem : navigation
        property Item commandRoot: null
        readonly property list<ActionControl> commands: (commandRoot ? navigation.collectCommands(commandRoot) : navigation.contentCommands).filter(item => !item.accessKey)
        // A removed/replaced subtree must not redirect Enter to another window.
        onCommandRootChanged: if (visible) close()
        actions: commands
        function available(index: int): bool {
            const command = commands[index];
            return !!command && command.visible && command.enabled && command.interactive;
        }
        function labelFor(index: int): string {
            const command = commands[index];
            return command ? command.accessibleName || command.objectName : "";
        }
        maximumVisibleItems: 7
        accessibleName: qsTr("Content actions")
        listObjectName: "detailsCommandMenu"
        onTriggered: function (action) { (action as ActionControl)?.activate(); }
    }
    Shortcut {
        sequence: "Alt+J"
        enabled: navigation.headerShortcutsEnabled && !navigation.popupOpen && commandMenu.commands.length > 0
        autoRepeat: false
        onActivated: navigation.openCommandMenu()
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
            required property ActionControl modelData
            required property int index
            readonly property string sequence: navigation ? navigation.shortcutFor(modelData) : ""
            Shortcut {
                sequence: shortcutSlot.sequence
                enabled: !!shortcutSlot.sequence && navigation.headerShortcutsEnabled && !navigation.popupOpen
                autoRepeat: false
                onActivated: navigation.triggerHeader(shortcutSlot.index)
            }
        }
    }

}
