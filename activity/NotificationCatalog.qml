import QtQuick

// Native app-group windows only; NotificationTimeline owns the record windows.
// No local grouping/search. Read generations never own mutations or group resolution.
Item {
    id: catalog
    required property NotificationState store
    property bool active: false
    property string query: ""
    property string revealKey: ""
    property var apps: []
    property string rootError: ""
    property bool rootBusy: false
    property bool rootDirty: false
    property int rootGeneration: 0
    property var nextOffset: null
    property string epoch: ""
    property string revision: ""
    property var staging: []
    property string stagingEpoch: ""
    property string stagingRevision: ""
    property var anchor: null
    readonly property bool hasMore: nextOffset !== null

    function refresh(): void {
        rootDirty = true;
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
    function invalidate(): void {
        rootGeneration++;
        rootBusy = false;
        staging = [];
        nextOffset = null;
        rootDirty = true;
    }
    function failRead(message: string): void {
        rootError = message;
        staging = [];
    }
    function receive(context: var, value: var, error: string, code: string): void {
        if (context.resolve || context.view !== "apps" || context.query !== query || context.generation !== rootGeneration) return;
        rootBusy = false;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") {
            staging = [];
            refresh();
            return;
        }
        if (error || !NotificationValidation.envelope(value, "apps", query)) {
            failRead(error || qsTr("Invalid notification center response"));
            return;
        }
        acceptApps(context, value);
        if (active && store.backend.ready && rootDirty) debounce.restart();
    }
    function validSummary(app: var): bool {
        return NotificationValidation.token(app?.key) && NotificationValidation.preview(app.latest) && app.latest.app_key === app.key
            && NotificationValidation.integerIn(app.count, 1, 5200) && NotificationValidation.integerIn(app.total_count, app.count, 5200);
    }
    function validAppPage(value: var, offset: int): bool {
        if (!Array.isArray(value.apps) || value.apps.length > 50 || !value.apps.every(validSummary)) return false;
        return NotificationValidation.integerIn(value.total_apps, 0, 5200)
            && NotificationValidation.pageEnds(value, offset, value.apps.length, value.total_apps);
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
            failRead(qsTr("Invalid notification app page")); return;
        }
        const next = base.concat(value.apps);
        if (new Set(next.map(a => a.key)).size !== next.length || next.length > value.total_apps) {
            failRead(qsTr("Notification app page did not advance")); return;
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
    }
    onQueryChanged: {
        invalidate(); apps = [];
        rootError = ""; refresh();
    }
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
        }
    }
    Connections {
        target: catalog.store
        function onObservedHistoryRevisionChanged(): void { catalog.refresh(); }
        function onCollectionChanged(): void { catalog.invalidate(); catalog.refresh(); }
        function onDataGenerationChanged(): void { catalog.invalidate(); catalog.rootError = qsTr("Notifications unavailable"); }
        function onCenterResponse(context: var, value: var, error: string, code: string): void { catalog.receive(context, value, error, code); }
    }
    Connections {
        target: catalog.store.backend
        function onReadyChanged(): void { if (catalog.store.backend.ready) catalog.refresh(); }
        function onEventGapDetected(): void { catalog.refresh(); }
    }
}
