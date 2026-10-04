import QtQuick

// Process-local presentation only. Never holds payloads, credentials, operation
// IDs, control values or QObject references. Domains validate the available tabs.
Item {
    required property ChooserController controller
    property bool presentationOpen: controller.detailsOpen
    onPresentationOpenChanged: rememberPresentation()
    property string key: ""
    property string tab: ""
    property string initialTab: ""
    property list<string> tabs: []
    property string activeKey: ""
    property string activeTab: ""
    property bool restoring: false
    property var records: Object.create(null)
    readonly property bool current: enabled && !restoring && key.length > 0 && key === activeKey && tab === activeTab

    signal restoreRequested(bool open, string tab)
    signal contextChanging(bool changedResult)
    signal contextRestored(bool changedResult)

    function validTab(value: string): string {
        return tabs.indexOf(value) >= 0 ? value : (tabs[0] || "");
    }
    function rememberPresentation(): void {
        if (!current || !controller.uiActive || (!presentationOpen && !records[key]))
            return;
        const record = records[key] || {pages: Object.create(null)};
        record.open = presentationOpen;
        record.tab = activeTab;
        records[key] = record;
    }
    function synchronize(): void {
        if (!enabled || restoring)
            return;
        const changed = activeKey !== key;
        const record = records[key];
        const nextTab = validTab(changed ? (record ? record.tab : initialTab) : tab);
        if (!changed && nextTab === activeTab)
            return;
        contextChanging(changed);
        restoring = true;
        activeKey = key;
        activeTab = nextTab;
        // Expansion belongs to the surface, not the newly selected result.
        // Per-result memory restores tabs/locations, never flips the list mode.
        restoreRequested(key.length > 0 && presentationOpen, nextTab);
        restoring = false;
        rememberPresentation();
        contextRestored(changed);
    }
    function pageState(pageTab: string): var {
        const record = records[activeKey];
        return record && record.pages[pageTab] ? record.pages[pageTab] : ({});
    }
    function rememberPage(pageTab: string, values: var): void {
        if (!current || !controller.uiActive || !presentationOpen || pageTab !== activeTab || !records[activeKey])
            return;
        const pages = records[activeKey].pages;
        pages[pageTab] = Object.assign({}, pages[pageTab] || ({}), values);
    }
    onKeyChanged: Qt.callLater(synchronize)
    onTabChanged: Qt.callLater(synchronize)
    onTabsChanged: Qt.callLater(synchronize)
    onEnabledChanged: {
        if (!enabled) {
            activeKey = "";
            activeTab = "";
        } else {
            Qt.callLater(synchronize);
        }
    }
    Component.onCompleted: Qt.callLater(synchronize)
}
