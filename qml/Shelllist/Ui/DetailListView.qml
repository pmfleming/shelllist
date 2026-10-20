import QtQuick
import Shelllist.Core as Core

// Virtualized read-only detail content. DetailsNavigation uses the same
// non-highlighted Tab fallback and PageUp/PageDown scrolling as DetailFlickable.
ListView {
    id: page
    property ChooserMemory viewMemory: null
    property string memoryTab: ""
    property string restoredKey: ""
    property string restoredTab: ""
    property bool restoringScroll: false
    readonly property bool scrollSuspended: viewportAnchor !== null
    property bool tearingDown: false
    readonly property Core.KeyedListModel keyedModel: model as Core.KeyedListModel
    property var viewportAnchor: null

    function captureAnchor(): void {
        if (viewportAnchor || !keyedModel) return;
        const index = firstVisibleIndex();
        const row = index >= 0 ? itemAtIndex(index) : null;
        viewportAnchor = {key: index >= 0 ? keyedModel.get(index).resultKey : "",
            offset: row ? row.y - contentY : 0, attempts: 0, stable: 0};
    }
    function cancelAnchor(): void {
        restoreRetry.stop();
        viewportAnchor = null;
    }
    function finishAnchor(): void {
        cancelAnchor();
        rememberScroll();
    }
    function restoreAnchor(): void {
        restoreRetry.stop();
        if (!viewportAnchor) return;
        if (tearingDown || !visible || !keyedModel) { cancelAnchor(); return; }
        cancelFlick();
        forceLayout();
        const anchor = viewportAnchor;
        const index = keyedModel.currentKeys().indexOf(anchor.key);
        if (index < 0) { finishAnchor(); return; }
        let item = itemAtIndex(index);
        if (!item || item.height <= 0) {
            positionViewAtIndex(index, ListView.Beginning);
            forceLayout();
            item = itemAtIndex(index);
        }
        // Keep one key/offset across incubation and variable-height refinement.
        // Two agreeing frames settle it; never capture an intermediate gap.
        const ready = item && item.height > 0;
        anchor.stable = ready && Math.abs(item.y - contentY - anchor.offset) < 1 ? anchor.stable + 1 : 0;
        if (ready) contentY = Math.max(originY, Math.min(originY + Math.max(0, contentHeight - height), item.y - anchor.offset));
        if (anchor.stable < 2 && anchor.attempts++ < 32) { restoreRetry.restart(); return; }
        finishAnchor();
    }
    Timer { id: restoreRetry; interval: 16; onTriggered: page.restoreAnchor() }
    onMovementStarted: cancelAnchor()

    function firstVisibleIndex(): int {
        // The viewport edge can land in delegate spacing after ListView refines
        // variable-height estimates. Find an actual visible row, not that gap.
        for (let y = Math.max(originY, contentY); y < contentY + height; y += Math.max(1, spacing + 1)) {
            const index = indexAt(width / 2, y);
            if (index >= 0) return index;
        }
        return -1;
    }
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
    onVisibleChanged: {
        if (visible) Qt.callLater(restoreScroll);
        else cancelAnchor();
    }
    Component.onCompleted: Qt.callLater(restoreScroll)
    Component.onDestruction: { tearingDown = true; cancelAnchor(); }
    Connections {
        target: page.viewMemory
        function onContextRestored(): void { Qt.callLater(page.restoreScroll); }
    }
    // Detail rows are not result selection. Otherwise an inserted recent row
    // can make ListView reveal its implicit currentIndex=0 over our viewport.
    currentIndex: -1
    highlightFollowsCurrentItem: false
    clip: true
    boundsBehavior: Flickable.StopAtBounds
}
