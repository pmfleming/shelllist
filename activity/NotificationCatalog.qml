import QtQuick
import Shelllist.Ui as Ui

// Only native, bounded view snapshots live here. No grouping, ordering or search
// over a partially loaded frontend catalog. Read generations never own mutations.
Item {
    id: catalog
    required property NotificationState store
    property bool active: false
    property string query: ""
    property string appKey: ""
    property string selectedKey: ""
    property string revealKey: ""
    property var apps: []
    property var detail: ({})
    property int page: 1
    property bool pagePending: false
    property string pageError: ""
    property string rootError: ""
    property string detailError: ""
    property bool rootBusy: false
    property bool detailBusy: false
    property bool rootDirty: false
    property bool detailDirty: false
    property int rootGeneration: 0
    property int detailGeneration: 0
    property var nextOffset: null
    property string epoch: ""
    property string revision: ""
    property var staging: []
    property string stagingEpoch: ""
    property string stagingRevision: ""
    property var anchor: null
    property bool loaded: false
    readonly property bool hasMore: nextOffset !== null
    signal detailAccepted
    signal invalidating

    function position(key: string): var {
        const parts = key.split(":");
        return parts.length === 2 ? {id: Number(parts[0]), created: Number(parts[1])} : null;
    }
    function refresh(): void {
        rootDirty = true;
        detailDirty = true;
        if (active && store.backend.ready) debounce.restart();
    }
    function reloadApps(): void {
        if (rootBusy) { rootDirty = true; return; }
        rootGeneration++;
        rootDirty = false;
        rootError = "";
        staging = [];
        stagingEpoch = "";
        stagingRevision = "";
        anchor = revealKey || (apps.length ? apps[apps.length - 1].key : null);
        requestApps(0, true);
    }
    function requestApps(offset: int, replacing: bool): void {
        rootBusy = true;
        store.backend.queryCenter({view: "apps", query: query, offset: offset,
            epoch: offset ? (replacing ? stagingEpoch : epoch) : null,
            revision: offset ? (replacing ? stagingRevision : revision) : null,
            app_anchor: replacing ? anchor : null},
            {view: "apps", generation: rootGeneration, revision: store.observedHistoryRevision,
                query: query, offset: offset, replacing: replacing});
    }
    function loadMore(): void {
        if (!active || rootBusy || !hasMore || rootError) return;
        if (rootDirty) { reloadApps(); return; }
        requestApps(nextOffset, false);
    }
    function requestDetail(preserveAnchor: bool): void {
        detailGeneration++;
        detailDirty = false;
        if (!appKey) { detailBusy = false; detail = ({}); return; }
        detailError = "";
        detailBusy = true;
        const first = preserveAnchor && !pagePending && detail.entries?.length ? detail.entries[0] : null;
        store.backend.queryCenter({view: "app", query: query, app_key: appKey, page: page,
            page_anchor: first ? {id: first.id, created: first.created_unix_ms} : null,
            selected: position(selectedKey)},
            {view: "app", generation: detailGeneration, revision: store.observedHistoryRevision,
                query: query, appKey: appKey, selectedKey: selectedKey});
    }
    function setPage(value: string): void {
        const total = Number(detail.pages || 1);
        if (!/^[1-9][0-9]*$/.test(value) || Number(value) > total) {
            pageError = qsTr("Enter a page from 1 to %1").arg(total);
            return;
        }
        pageError = "";
        if (Number(value) === page) return;
        page = Number(value);
        pagePending = true;
        requestDetail(false);
    }
    function invalidate(): void {
        rootGeneration++;
        detailGeneration++;
        rootBusy = false;
        detailBusy = false;
        staging = [];
        nextOffset = null;
        rootDirty = true;
        detailDirty = true;
        invalidating();
    }
    function validPreview(item: var): bool {
        return Number.isSafeInteger(item?.id) && item.id > 0 && item.id <= 4294967295
            && Number.isSafeInteger(item.created_unix_ms) && item.created_unix_ms > 0
            && typeof item.app_key === "string" && item.app_key.length > 0
            && [item.app_name, item.app_icon, item.summary, item.body].every(text => typeof text === "string");
    }
    function validList(rows: var, max: int): bool {
        return Array.isArray(rows) && rows.length <= max && rows.every(validPreview)
            && new Set(rows.map(Ui.NotificationPresentation.recordKey)).size === rows.length;
    }
    function receive(context: var, value: var, error: string, code: string): void {
        if (context.resolve) return;
        const root = context.view === "apps";
        if (context.generation !== (root ? rootGeneration : detailGeneration) || context.query !== query)
            return;
        if (!root && (context.appKey !== appKey || context.selectedKey !== selectedKey)) return;
        if (root) rootBusy = false;
        else detailBusy = false;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") {
            if (root) { staging = []; rootDirty = true; }
            else detailDirty = true;
            refresh();
            return;
        }
        if (!error && (value?.query !== query || value.view !== context.view
                || typeof value.epoch !== "string" || !value.epoch.length
                || typeof value.revision !== "string" || !value.revision.length))
            error = qsTr("Invalid notification center response");
        if (error) {
            if (root) { rootError = error; staging = []; }
            else detailError = error;
            return;
        }
        if (root) acceptApps(context, value);
        else acceptDetail(value);
        if (active && store.backend.ready && (rootDirty || detailDirty)) debounce.restart();
    }
    function acceptApps(context: var, value: var): void {
        const base = context.replacing ? staging : apps;
        const priorEpoch = context.replacing ? stagingEpoch : epoch;
        const priorRevision = context.replacing ? stagingRevision : revision;
        if (context.offset && (priorEpoch !== value.epoch || priorRevision !== value.revision)) {
            staging = [];
            refresh();
            return;
        }
        if (!Array.isArray(value.apps) || value.apps.length > 50 || value.offset !== base.length
                || !Number.isInteger(value.total_apps) || value.total_apps < 0 || value.total_apps > 5200
                || typeof value.anchor_reached !== "boolean"
                || !value.apps.every(a => typeof a.key === "string" && a.key.length && validPreview(a.latest)
                    && a.latest.app_key === a.key && Number.isInteger(a.count) && a.count > 0
                    && Number.isInteger(a.total_count) && a.total_count >= a.count)
                || (value.next_offset !== null && (value.next_offset !== base.length + value.apps.length
                    || !value.apps.length || value.next_offset >= value.total_apps))
                || (value.next_offset === null && base.length + value.apps.length !== value.total_apps)) {
            rootError = qsTr("Invalid notification app page"); staging = []; return;
        }
        const next = base.concat(value.apps);
        if (new Set(next.map(a => a.key)).size !== next.length || next.length > value.total_apps) {
            rootError = qsTr("Notification app page did not advance"); staging = []; return;
        }
        if (context.replacing && value.next_offset !== null && !value.anchor_reached) {
            staging = next; stagingEpoch = value.epoch; stagingRevision = value.revision;
            if (active) requestApps(value.next_offset, true);
            else { staging = []; rootDirty = true; }
            return;
        }
        rootError = "";
        if (!store.equal(apps, next)) apps = next;
        staging = [];
        epoch = value.epoch; revision = value.revision; nextOffset = value.next_offset;
        loaded = true;
    }
    function acceptDetail(value: var): void {
        if (value.app_key !== appKey || !validList(value.overview, 3) || !validList(value.entries, 5)
                || !Number.isInteger(value.count) || value.count < 0 || value.count > 5200
                || !Number.isInteger(value.total_count) || value.total_count < value.count
                || value.pages !== Math.max(1, Math.ceil(value.count / 5))
                || !Number.isInteger(value.page) || value.page < 1 || value.page > value.pages
                || value.overview.some(n => n.app_key !== appKey) || value.entries.some(n => n.app_key !== appKey)
                || (value.selected !== null && Ui.NotificationPresentation.recordKey(value.selected) !== selectedKey)) {
            detailError = qsTr("Invalid notification detail page"); return;
        }
        detailError = "";
        page = value.page;
        pagePending = false;
        if (!store.equal(detail, value)) detail = value;
        detailAccepted();
    }
    onQueryChanged: {
        invalidate(); apps = []; detail = ({}); page = 1; loaded = false;
        rootError = ""; detailError = ""; refresh();
    }
    onAppKeyChanged: {
        detailGeneration++; detailBusy = false; detail = ({}); page = 1; pagePending = false; pageError = "";
        detailDirty = true;
        if (active && store.backend.ready) Qt.callLater(requestDetail, false);
    }
    onSelectedKeyChanged: if (active && appKey && store.backend.ready) Qt.callLater(requestDetail, true)
    onActiveChanged: {
        if (active) refresh();
        else { debounce.stop(); invalidate(); }
    }
    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            if (!catalog.active || !catalog.store.backend.ready) return;
            if (catalog.rootDirty && !catalog.rootBusy) catalog.reloadApps();
            if (catalog.detailDirty && !catalog.detailBusy) catalog.requestDetail(true);
        }
    }
    Connections {
        target: catalog.store
        function onObservedHistoryRevisionChanged(): void { catalog.refresh(); }
        function onDataGenerationChanged(): void { catalog.invalidate(); catalog.rootError = qsTr("Notifications unavailable"); }
        function onCenterResponse(context: var, value: var, error: string, code: string): void { catalog.receive(context, value, error, code); }
    }
    Connections {
        target: catalog.store.backend
        function onReadyChanged(): void { if (catalog.store.backend.ready) catalog.refresh(); }
    }
}
