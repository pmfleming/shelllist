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
    }
    function integerIn(value: var, minimum: double, maximum: double): bool {
        return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
    }
    function token(value: var): bool { return typeof value === "string" && value.length > 0; }
    function validPreview(item: var): bool {
        return integerIn(item?.id, 1, 4294967295) && integerIn(item.created_unix_ms, 1, Number.MAX_SAFE_INTEGER)
            && token(item.app_key)
            && [item.app_name, item.app_icon, item.summary, item.body].every(text => typeof text === "string");
    }
    function validList(rows: var, max: int): bool {
        return Array.isArray(rows) && rows.length <= max
            && rows.every(item => validPreview(item) && item.app_key === appKey)
            && new Set(rows.map(Ui.NotificationPresentation.recordKey)).size === rows.length;
    }
    function ownsRead(context: var): bool {
        if (context.resolve || context.query !== query) return false;
        if (context.view === "apps") return context.generation === rootGeneration;
        return context.view === "app" && context.generation === detailGeneration
            && context.appKey === appKey && context.selectedKey === selectedKey;
    }
    function validEnvelope(value: var, view: string): bool {
        return value?.query === query && value.view === view && token(value.epoch) && token(value.revision);
    }
    function failRead(root: bool, message: string): void {
        if (root) { rootError = message; staging = []; }
        else detailError = message;
    }
    function receive(context: var, value: var, error: string, code: string): void {
        if (!ownsRead(context)) return;
        const root = context.view === "apps";
        if (root) rootBusy = false;
        else detailBusy = false;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") {
            if (root) staging = [];
            refresh();
            return;
        }
        if (error || !validEnvelope(value, context.view)) {
            failRead(root, error || qsTr("Invalid notification center response"));
            return;
        }
        if (root) acceptApps(context, value);
        else acceptDetail(value);
        if (active && store.backend.ready && (rootDirty || detailDirty)) debounce.restart();
    }
    function validSummary(app: var): bool {
        return token(app?.key) && validPreview(app.latest) && app.latest.app_key === app.key
            && integerIn(app.count, 1, 5200) && integerIn(app.total_count, app.count, 5200);
    }
    function validAppPage(value: var, offset: int): bool {
        if (!Array.isArray(value.apps) || value.apps.length > 50 || !value.apps.every(validSummary)) return false;
        if (value.offset !== offset || !integerIn(value.total_apps, 0, 5200) || typeof value.anchor_reached !== "boolean") return false;
        const end = offset + value.apps.length;
        if (value.next_offset === null) return end === value.total_apps;
        return value.apps.length > 0 && value.next_offset === end && end < value.total_apps;
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
        if (!validAppPage(value, base.length)) {
            failRead(true, qsTr("Invalid notification app page")); return;
        }
        const next = base.concat(value.apps);
        if (new Set(next.map(a => a.key)).size !== next.length || next.length > value.total_apps) {
            failRead(true, qsTr("Notification app page did not advance")); return;
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
                || !integerIn(value.count, 0, 5200) || !integerIn(value.total_count, value.count, 5200)
                || value.pages !== Math.max(1, Math.ceil(value.count / 5))
                || !integerIn(value.page, 1, value.pages)
                || (value.selected !== null && Ui.NotificationPresentation.recordKey(value.selected) !== selectedKey)) {
            detailError = qsTr("Invalid notification detail page"); return;
        }
        detailError = "";
        page = value.page;
        pagePending = false;
        if (!store.equal(detail, value)) detail = value;
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
        function onEventGapDetected(): void { catalog.refresh(); }
    }
}
