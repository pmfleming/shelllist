pragma ComponentBehavior: Bound
import QtQuick

// One shared command registry/menu. Field discovery, transactions and restoration
// stay in DetailsNavigation; this collaborator never stores field state.
Item {
    id: registry
    required property Item menuParent
    property Item contentItem: null
    property Item headerContentItem: contentItem
    property Item additionalCommandItem: null
    property Item currentTarget: null
    property bool shortcutsEnabled: false
    property bool blocked: false
    readonly property list<SurfaceActionRow> actionRows: uniqueItems(collectActionRows(headerContentItem).concat(collectActionRows(additionalCommandItem)))
    readonly property list<ActionControl> headerButtons: actionRows.filter(row => row.headerCommands).reduce((buttons, row) => buttons.concat(Array.from(row.buttons)), [])
    readonly property list<ActionControl> contentCommands: uniqueItems(collectCommands(contentItem).concat(collectCommands(additionalCommandItem))).filter(item => commandInScope(item))
    readonly property list<ActionControl> commandButtons: headerButtons.concat(contentCommands.filter(item => !!item.accessKey))
    readonly property bool popupOpen: commandMenu.visible || actionRows.some(row => row.popupOpen)
    signal shortcutInvoked

    function uniqueItems(items: var): var {
        return items.filter((item, index) => items.indexOf(item) === index);
    }
    function collectActionRows(item: Item): var {
        if (!item || !item.visible || item instanceof ModalFrame || (item as DetailSection)?.informationOnly)
            return [];
        if (item instanceof SurfaceActionRow) return [item];
        let result = [];
        for (const child of item.children) result = result.concat(collectActionRows(child));
        return result;
    }
    function collectCommands(item: Item): var {
        if (!item || !item.visible || item instanceof DetailsHeader || item instanceof DetailsTabBar || item instanceof ModalFrame)
            return [];
        const actionRow = item as SurfaceActionRow;
        if (actionRow && actionRow.headerCommands) return [];
        const action = item as ActionControl;
        let result = action && !(action instanceof ToggleRow || action instanceof ToggleSwitch) ? [action] : [];
        for (const child of item.children) result = result.concat(collectCommands(child));
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
        if (!button || commandButtons.indexOf(button) < 0
                || !["Alt", "Ctrl"].includes(button.accessModifier)
                || !(button.accessModifier === "Ctrl" ? /^[A-Z]$/ : /^[A-IK-RT-Z]$/).test(button.accessKey)
                || commandButtons.filter(other => other.accessKey === button.accessKey
                    && other.accessModifier === button.accessModifier).length !== 1)
            return "";
        return button.accessModifier + "+" + button.accessKey;
    }
    function trigger(index: int): void {
        const button = commandButtons[index];
        if (!shortcutsEnabled || blocked || !button || !button.visible || !button.enabled || !button.interactive) return;
        shortcutInvoked();
        button.activate();
    }
    function closeRows(): void { for (const row of actionRows) row.closePopup(); }
    function closeMenu(): void { commandMenu.close(); }
    function closeAll(): void { closeMenu(); closeRows(); }
    onShortcutsEnabledChanged: if (!shortcutsEnabled) closeAll()
    function openMenu(root: Item): void {
        if (!shortcutsEnabled || blocked) return;
        commandMenu.commandRoot = root;
        if (commandMenu.commands.length > 0) {
            commandMenu.invalidated = false;
            commandMenu.open();
        }
    }
    ActionMenu {
        id: commandMenu
        parent: registry.additionalCommandItem && registry.additionalCommandItem.visible ? registry.additionalCommandItem : registry.menuParent
        property Item commandRoot: null
        readonly property list<ActionControl> commands: (commandRoot ? registry.collectCommands(commandRoot) : registry.contentCommands).filter(item => !item.accessKey || item.includeInCommandMenu)
        property bool invalidated: false
        // Reject activation immediately, then close outside discovery bindings:
        // returning native focus may itself change the scoped command set.
        function invalidate(): void {
            if (!visible) return;
            invalidated = true;
            Qt.callLater(closeInvalidated);
        }
        function closeInvalidated(): void { if (invalidated) close(); }
        onCommandRootChanged: invalidate()
        onCommandsChanged: invalidate()
        actions: commands
        function available(index: int): bool {
            const command = commands[index];
            return !invalidated && !!command && command.visible && command.enabled && command.interactive;
        }
        function labelFor(index: int): string {
            const command = commands[index];
            return command ? command.accessibleName || command.objectName : "";
        }
        maximumVisibleItems: 7
        accessibleName: qsTranslate("DetailsNavigation", "Content actions")
        listObjectName: "detailsCommandMenu"
        onTriggered: function (action) { (action as ActionControl)?.activate(); }
    }
    Shortcut {
        sequence: "Alt+J"
        enabled: registry.shortcutsEnabled && !registry.blocked && commandMenu.commands.length > 0
        autoRepeat: false
        onActivated: registry.openMenu(null)
    }
    Repeater {
        model: registry.commandButtons
        delegate: Item {
            id: shortcutSlot
            required property ActionControl modelData
            required property int index
            readonly property string sequence: registry ? registry.shortcutFor(modelData) : ""
            Shortcut {
                sequence: shortcutSlot.sequence
                enabled: !!shortcutSlot.sequence && registry.shortcutsEnabled && !registry.blocked
                autoRepeat: false
                onActivated: registry.trigger(shortcutSlot.index)
            }
        }
    }
}
