import QtQuick
import QtQuick.Controls as Controls
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
    readonly property real rowWidth: width - (contentHeight > height ? scrollBar.width + Theme.spacingSm : 0)
    Controls.ScrollBar.vertical: DetailScrollBar {
        id: scrollBar
        objectName: "detailListScrollBar"
        policy: page.contentHeight > page.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
        onPressedChanged: if (pressed) page.cancelAnchor()
    }

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
        const bottom = contentY + height;
        for (let y = Math.max(originY, contentY); y < bottom; y += Math.max(1, spacing + 1)) {
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
        const state = viewMemory.pageState(memoryTab);
        const saved = Number(state.scroll) || 0;
        restoredKey = viewMemory.activeKey; restoredTab = memoryTab;
        // A recreated virtual list initially estimates heights from its first
        // rows. Restore a keyed row/offset, not pixels relative to that estimate:
        // ListView can move originY as it instantiates the saved viewport.
        if (keyedModel && state.scrollKey && keyedModel.currentKeys().includes(state.scrollKey)) {
            viewportAnchor = {key: state.scrollKey, offset: Number(state.scrollOffset) || 0, attempts: 0, stable: 0};
            restoringScroll = false;
            Qt.callLater(restoreAnchor);
            return;
        }
        contentY = originY + Math.max(0, Math.min(Math.max(0, contentHeight - height), saved));
        restoringScroll = false;
    }
    function rememberScroll(): void {
        if (visible && !tearingDown && !scrollSuspended && !restoringScroll && viewMemory && restoredKey === viewMemory.key && restoredTab === memoryTab) {
            const index = keyedModel ? firstVisibleIndex() : -1;
            const row = index >= 0 ? itemAtIndex(index) : null;
            viewMemory.rememberPage(memoryTab, {scroll: Math.max(0, contentY - originY),
                scrollKey: row ? keyedModel.get(index).resultKey : "", scrollOffset: row ? row.y - contentY : 0});
        }
    }
    // indexAt() can force layout; never inspect delegates inside ListView's
    // own contentY/layout notification while it is replacing the viewport.
    onContentYChanged: Qt.callLater(rememberScroll)
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
