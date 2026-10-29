pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Bounded, keyed presentation for collections containing native editors or
// commands. The owner ends/discards its field session before calling showPage.
// Never dispatches domain operations or stores editor buffers.
Item {
    id: pager
    property string title: ""
    property var items: []
    property int pageSize: 8
    property string contextKey: ""
    property string anchorKey: ""
    property string pinnedKey: ""
    property int offset: 0
    property bool blocked: false
    property ChooserMemory viewMemory: null
    property string memoryTab: ""
    property string memoryKey: ""
    readonly property int start: {
        const anchor = items.findIndex(item => item.id === anchorKey);
        let first = anchor >= 0 ? anchor : Math.min(offset, Math.max(0, items.length - pageSize));
        // An incoming insertion/reorder must not destroy the active editor.
        const pinned = items.findIndex(item => item.id === pinnedKey);
        if (pinned >= 0 && (pinned < first || pinned >= first + pageSize))
            first = Math.max(0, pinned - pageSize + 1);
        return first;
    }
    readonly property var visibleItems: items.slice(start, start + pageSize)
    signal pageRequested(int offset)
    function showPage(value: int): void {
        offset = Math.max(0, Math.min(value, Math.max(0, items.length - 1)));
        anchorKey = items[offset]?.id || "";
        if (viewMemory && memoryKey) {
            const state = {};
            state[memoryKey] = {offset: offset, anchorKey: anchorKey};
            viewMemory.rememberPage(memoryTab, state);
        }
    }
    function restorePage(): void {
        if (!viewMemory || !memoryKey || pinnedKey) return;
        const saved = viewMemory.pageState(memoryTab)[memoryKey] || {};
        offset = Number(saved.offset) || 0;
        anchorKey = saved.anchorKey || "";
    }
    onContextKeyChanged: { offset = 0; anchorKey = ""; pinnedKey = ""; Qt.callLater(restorePage); }
    Component.onCompleted: Qt.callLater(restorePage)
    Connections {
        target: pager.viewMemory
        function onContextRestored(): void { Qt.callLater(pager.restorePage); }
    }
    onItemsChanged: if (pinnedKey && items.some(item => item.id === pinnedKey)) {
        offset = start;
        anchorKey = items[start]?.id || "";
    }
    implicitHeight: heading.implicitHeight
    Layout.fillWidth: true
    Loader {
        id: heading
        width: parent.width
        active: pager.visible
        sourceComponent: RowLayout {
            spacing: Theme.spacingSm
            SectionHeading {
                Layout.fillWidth: true
                title: pager.items.length > pager.pageSize
                    ? qsTr("%1 · %2–%3 of %4").arg(pager.title).arg(pager.start + 1).arg(pager.start + pager.visibleItems.length).arg(pager.items.length)
                    : pager.title
            }
            SurfaceActionRow {
                Layout.preferredWidth: 2 * nominalControlHeight + gap
                Layout.preferredHeight: implicitHeight
                visible: pager.items.length > pager.pageSize
                headerCommands: false
                compactSecondaryActions: true
                actionObjectNamePrefix: pager.objectName + "-"
                actions: [
                    {id: "previous", label: qsTr("Previous %1").arg(pager.title), icon: "chevron_left", enabled: !pager.blocked && pager.start > 0, presentation: {group: "toolbar"}},
                    {id: "next", label: qsTr("Next %1").arg(pager.title), icon: "chevron_right", enabled: !pager.blocked && pager.start + pager.pageSize < pager.items.length, presentation: {group: "toolbar"}}
                ]
                onTriggered: function(id) { pager.pageRequested(id === "previous" ? Math.max(0, pager.start - pager.pageSize) : pager.start + pager.pageSize); }
            }
        }
    }
}
