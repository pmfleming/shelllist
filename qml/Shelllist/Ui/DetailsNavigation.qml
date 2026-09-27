import QtQuick

// A browse cursor is separate from native editor focus. Only opted-in chooser
// surfaces use this boundary; dialogs and native popups keep their own keys.
FocusScope {
    id: navigation

    property Item contentItem: null
    readonly property var targets: collectTargets(contentItem)
    property Item currentTarget: null
    property bool awaitingContent: false
    property Item editorTarget: null
    readonly property Item focusedTarget: targetForFocus(Window.window ? Window.window.activeFocusItem : null)
    readonly property bool popupOpen: (currentTarget as DropDownList)?.popup.visible ?? false
    readonly property bool editing: editorTarget !== null && (activeFocus || popupOpen)
    readonly property bool browsing: browseCursor.activeFocus && !editing

    signal exitRequested

    function collectTargets(item: Item): var {
        if (!item || !item.visible || item instanceof DetailsTabBar)
            return [];
        // Composite inputs are one browsing stop, not their internal buttons.
        if (item instanceof TextField || item instanceof DropDownList || item instanceof SegmentedControl || item instanceof ValueSlider || item instanceof LabeledValueSlider || item instanceof ActionControl || item.activeFocusOnTab)
            return [item];
        let result = [];
        let headers = [];
        const page = item as DetailFlickable;
        const children = page ? page.navigationContent.children : item.children;
        for (let child of children) {
            if (child instanceof DetailsHeader)
                headers = headers.concat(collectTargets(child));
            else
                result = result.concat(collectTargets(child));
        }
        // A page stop keeps read-only charts/information keyboard-scrollable.
        if (page)
            result.push(page);
        // Content first; header actions are still explicitly reachable.
        return result.concat(headers);
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
        return item instanceof TextField || item instanceof DropDownList || item instanceof SegmentedControl || item instanceof ValueSlider || item instanceof LabeledValueSlider || item instanceof ToggleRow || item instanceof ToggleSwitch;
    }
    function isHeaderTarget(item: Item): bool {
        while (item && item !== navigation) {
            if (item instanceof DetailsHeader)
                return true;
            item = item.parent;
        }
        return false;
    }
    function selectContent(): void {
        currentTarget = targets.length > 0 ? targets[0] : null;
        awaitingContent = !currentTarget || isHeaderTarget(currentTarget);
    }
    function focusContent(reset: bool): void {
        editorTarget = null;
        if (reset || targets.indexOf(currentTarget) < 0)
            selectContent();
        browseCursor.forceActiveFocus(Qt.OtherFocusReason);
        revealTarget();
    }
    function move(delta: int): void {
        awaitingContent = false;
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
    function revealTarget(): void {
        if (!currentTarget)
            return;
        let ancestor = currentTarget.parent;
        while (ancestor && ancestor !== navigation) {
            const page = ancestor as DetailFlickable;
            if (page) {
                page.revealItem(currentTarget);
                return;
            }
            ancestor = ancestor.parent;
        }
    }
    function enterEditor(): void {
        awaitingContent = false;
        const item = currentTarget;
        if (!item || !item.enabled || item instanceof DetailFlickable)
            return;
        const field = item as TextField;
        const labeled = item as LabeledValueSlider;
        const action = item as ActionControl;
        const segments = item as SegmentedControl;
        if ((field && field.readOnly) || (action && !action.interactive) || (segments && !segments.interactive))
            return;
        editorTarget = item;
        if (field)
            field.focusInput(false);
        else if (labeled)
            labeled.focusInput();
        else
            item.forceActiveFocus(Qt.OtherFocusReason);
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
        currentTarget = focusedTarget;
        editorTarget = focusedTarget;
        awaitingContent = false;
    }
    onActiveFocusChanged: if (!activeFocus && !popupOpen)
        editorTarget = null
    onTargetsChanged: {
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
        Accessible.description: navigation.editable(navigation.currentTarget) ? qsTr("Right to edit") : ""
        Keys.onPressed: function (event) {
            if (event.modifiers !== Qt.NoModifier)
                return;
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
                const action = navigation.currentTarget as ActionControl;
                if (action && !navigation.editable(action) && !event.isAutoRepeat)
                    action.activate();
            } else
                return;
            event.accepted = true;
        }
    }

    // Parenting to the target keeps the outline attached during scrolling and
    // layout changes. It neither changes hit geometry nor takes input/focus.
    FocusRing {
        parent: navigation.currentTarget || navigation
        active: navigation.browsing || (navigation.editing && !navigation.focusedTarget)
        ringColor: Theme.accent
        cornerRadius: Theme.controlRadius
    }
}
