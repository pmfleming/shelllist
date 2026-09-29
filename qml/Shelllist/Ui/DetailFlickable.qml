import QtQuick

Flickable {
    id: page

    // Direct children are positioned by the Column. Give them width and
    // explicit/implicit height, not vertical anchors (including anchors.fill).
    // Anchor content inside an unanchored Item/DetailCard when it needs a slot.
    default property alias cards: cardColumn.data
    readonly property alias navigationContent: cardColumn
    property int cardSpacing: Theme.verticalSpacing(Theme.spacingMd, Theme.densityScale(height, 0))
    property bool revealFocusedControl: false
    property ChooserMemory viewMemory: null
    property string memoryTab: ""
    property string restoredKey: ""
    property string restoredTab: ""
    property bool restoringScroll: false

    function restoreScroll(): void {
        if (tearingDown || !visible || !viewMemory || !viewMemory.current || memoryTab !== viewMemory.activeTab)
            return;
        restoringScroll = true;
        if (restoredKey !== viewMemory.activeKey || restoredTab !== memoryTab)
            cancelFlick();
        const saved = Number(viewMemory.pageState(memoryTab).scroll) || 0;
        contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), saved));
        restoredKey = viewMemory.activeKey;
        restoredTab = memoryTab;
        restoringScroll = false;
    }
    onContentYChanged: if (visible && !restoringScroll && !tearingDown && viewMemory && restoredKey === viewMemory.key && restoredTab === memoryTab)
        viewMemory.rememberPage(memoryTab, {scroll: Math.max(0, contentY)})
    onContentHeightChanged: Qt.callLater(restoreScroll)
    onHeightChanged: Qt.callLater(restoreScroll)
    onMemoryTabChanged: Qt.callLater(restoreScroll)
    onVisibleChanged: if (visible)
        Qt.callLater(restoreScroll)
    Component.onCompleted: Qt.callLater(restoreScroll)
    Connections {
        target: page.viewMemory
        function onContextRestored(): void { Qt.callLater(page.restoreScroll); }
    }
    property bool tearingDown: false
    Component.onDestruction: tearingDown = true
    readonly property Item focusedControl: Window.window ? Window.window.activeFocusItem : null

    // Opt-in for form workspaces: keyboard focus must not disappear below the
    // viewport when a wide inspector stacks vertically on a small display.
    function revealFocus(): void {
        if (tearingDown || !revealFocusedControl || !focusedControl)
            return;
        revealItem(focusedControl);
    }
    function revealItem(item: Item): void {
        let ancestor = item.parent;
        while (ancestor && ancestor !== contentItem)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        // Commit initial geometry/bookkeeping before a newer explicit reveal.
        // Otherwise queued restoreScroll can overwrite an unrecorded movement.
        cardColumn.forceLayout();
        restoreScroll();
        const position = item.mapToItem(contentItem, 0, 0);
        if (position.y < contentY)
            contentY = Math.max(0, position.y - Theme.spacingSm);
        else if (position.y + item.height > contentY + height)
            contentY = Math.max(0, Math.min(contentHeight - height, position.y + item.height - height + Theme.spacingSm));
    }
    onFocusedControlChanged: Qt.callLater(revealFocus)

    contentWidth: width
    contentHeight: cardColumn.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true

    Column {
        id: cardColumn
        width: page.width
        spacing: page.cardSpacing
    }
}
