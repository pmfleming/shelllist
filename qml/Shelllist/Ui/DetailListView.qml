import QtQuick

// Virtualized read-only detail content. DetailsNavigation uses the same
// non-highlighted Tab fallback and PageUp/PageDown scrolling as DetailFlickable.
ListView {
    id: page
    property ChooserMemory viewMemory: null
    property string memoryTab: ""
    property string restoredKey: ""
    property string restoredTab: ""
    property bool restoringScroll: false
    property bool scrollSuspended: false
    property bool tearingDown: false

    function restoreScroll(): void {
        if (tearingDown || scrollSuspended || !visible || !count || !viewMemory || !viewMemory.current || memoryTab !== viewMemory.activeTab) return;
        // Unlike a Column, ListView refines height/origin estimates while
        // scrolling. Reapplying a pixel offset on every refinement jumps.
        if (restoredKey === viewMemory.activeKey && restoredTab === memoryTab) return;
        restoringScroll = true;
        cancelFlick();
        const saved = Number(viewMemory.pageState(memoryTab).scroll) || 0;
        contentY = originY + Math.max(0, Math.min(Math.max(0, contentHeight - height), saved));
        restoredKey = viewMemory.activeKey; restoredTab = memoryTab;
        restoringScroll = false;
    }
    function rememberScroll(): void {
        if (visible && !tearingDown && !scrollSuspended && !restoringScroll && viewMemory && restoredKey === viewMemory.key && restoredTab === memoryTab)
            viewMemory.rememberPage(memoryTab, {scroll: Math.max(0, contentY - originY)});
    }
    onContentYChanged: rememberScroll()
    onContentHeightChanged: Qt.callLater(restoreScroll)
    onHeightChanged: Qt.callLater(restoreScroll)
    onMemoryTabChanged: Qt.callLater(restoreScroll)
    onVisibleChanged: if (visible) Qt.callLater(restoreScroll)
    Component.onCompleted: Qt.callLater(restoreScroll)
    Component.onDestruction: tearingDown = true
    Connections {
        target: page.viewMemory
        function onContextRestored(): void { Qt.callLater(page.restoreScroll); }
    }
    clip: true
    boundsBehavior: Flickable.StopAtBounds
}
