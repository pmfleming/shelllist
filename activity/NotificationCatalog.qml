import QtQuick

// Native app-group windows only. Exact group routes may scan bounded windows;
// ordinary refresh/activation never replays the previously browsed prefix.
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
    property var staging: null
    property int windowOffset: 0
    readonly property int cacheLimit: 200
    // Reserve a complete native page; byte-limited short pages must not make
    // the following legitimate response overflow the window.
    readonly property bool cacheFull: apps.length + 50 > cacheLimit
    property var anchor: null
    property bool restartAtBeginning: false
    property bool readRestarted: false
    property bool resetViewport: false
    signal windowReplaced
    readonly property bool hasMore: nextOffset !== null
    signal revealFinished(bool found)

    function refresh(): void {
        rootDirty = true;
        if (active && store && store.backend.ready) debounce.restart();
    }
    function reloadApps(): void {
        if (!active || !store.backend.ready) return;
        if (rootBusy) { rootDirty = true; return; }
        const reset = restartAtBeginning;
        restartAtBeginning = false;
        startRead(reset || revealKey ? 0 : windowOffset, !reset, reset);
    }
    function startRead(offset: int, preserveExtent: bool, restarted: bool): void {
        rootGeneration++; rootDirty = false; rootError = "";
        staging = {apps: [], epoch: epoch, revision: revision, offset: offset};
        readRestarted = restarted;
        resetViewport = !preserveExtent || apps.length === 0 || !!revealKey;
        anchor = revealKey || (preserveExtent && apps.length ? apps[apps.length - 1].key : null);
        requestApps(offset, true);
    }
    function requestApps(offset: int, replacing: bool): void {
        rootBusy = true;
        const cursor = replacing ? staging : catalog;
        store.backend.queryCenter({view: "apps", query: query, offset: offset,
            epoch: offset ? cursor.epoch : null,
            revision: offset ? cursor.revision : null,
            app_anchor: replacing ? anchor : null},
            {view: "apps", generation: rootGeneration, revision: store.observedHistoryRevision,
                query: query, offset: offset, replacing: replacing, restarted: readRestarted});
    }
    function autoLoadMore(): void { if (!cacheFull) loadMore(); }
    function loadMore(): void {
        if (!active || !store.backend.ready || rootBusy || !hasMore || rootError) return;
        if (rootDirty) { reloadApps(); return; }
        if (cacheFull) startRead(nextOffset, false, false);
        else requestApps(nextOffset, false);
    }
    function showRecent(): void {
        if (active && store.backend.ready && !rootBusy) { revealKey = ""; startRead(0, false, false); }
    }
    function invalidate(): void {
        rootGeneration++; rootBusy = false; staging = null; anchor = null;
        rootDirty = true;
    }
    function clearCache(): void {
        invalidate(); apps = []; nextOffset = null; epoch = ""; revision = "";
        windowOffset = 0; revealKey = ""; rootError = "";
        restartAtBeginning = false; readRestarted = false;
    }
    function failRead(message: string): void {
        rootError = message; staging = null;
    }
    function staleRead(context: var): void {
        staging = null;
        if (context.restarted) { failRead(qsTr("Notification history changed; refresh again")); return; }
        restartAtBeginning = true;
        refresh();
    }
    function receive(context: var, value: var, error: string, code: string): void {
        if (!active || context.resolve || context.view !== "apps" || context.query !== query || context.generation !== rootGeneration) return;
        rootBusy = false;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") { staleRead(context); return; }
        if (error || !NotificationValidation.envelope(value, "apps", query)) {
            failRead(error || qsTr("Invalid notification center response")); return;
        }
        acceptPage(context, value);
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
    function acceptPage(context: var, value: var): void {
        const window = context.replacing ? staging : {apps: apps, epoch: epoch, revision: revision, offset: windowOffset};
        // Consume the unpublished rows and cursor together. Only an accepted
        // continuation installs another complete staging value.
        staging = null;
        if (!window) { failRead(qsTr("Notification read was superseded")); return; }
        if (context.offset && (window.epoch !== value.epoch || window.revision !== value.revision)) { staleRead(context); return; }
        if (!validAppPage(value, window.offset + window.apps.length)) {
            failRead(qsTr("Invalid notification app page")); return;
        }
        const next = window.apps.concat(value.apps);
        if (new Set(next.map(a => a.key)).size !== next.length || next.length > value.total_apps || next.length > cacheLimit) {
            failRead(qsTr("Notification app page did not advance")); return;
        }
        const fits = next.length + 50 <= cacheLimit;
        if (context.replacing && value.next_offset !== null && !value.anchor_reached && (revealKey || fits)) {
            // Exact lookup can scan without retaining its entire prefix.
            staging = {apps: fits ? next : [], epoch: value.epoch, revision: value.revision,
                offset: fits ? window.offset : value.next_offset};
            requestApps(value.next_offset, true);
            return;
        }
        publishWindow(context.replacing, value, next, window.offset);
    }
    function publishWindow(replacing: bool, value: var, next: var, offset: int): void {
        rootError = "";
        if (replacing) windowOffset = offset;
        if (!store.equal(apps, next)) apps = next;
        anchor = null;
        epoch = value.epoch; revision = value.revision; nextOffset = value.next_offset; readRestarted = false;
        if (replacing && resetViewport) windowReplaced();
        if (revealKey) {
            const found = next.some(app => app.key === revealKey);
            revealKey = "";
            revealFinished(found);
        }
    }
    // A newly resolved route must own its own anchor, not an in-flight normal
    // refresh whose anchor_reached flag refers to something else.
    onRevealKeyChanged: if (revealKey) { invalidate(); refresh(); }
    onQueryChanged: { clearCache(); refresh(); }
    onActiveChanged: {
        if (active) refresh();
        else { debounce.stop(); clearCache(); }
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
        function onDataGenerationChanged(): void { catalog.clearCache(); catalog.rootError = qsTr("Notifications unavailable"); }
        function onCenterResponse(context: var, value: var, error: string, code: string): void { catalog.receive(context, value, error, code); }
    }
    Connections {
        target: catalog.store.backend
        function onReadyChanged(): void { if (catalog.store.backend.ready) catalog.refresh(); }
        function onEventGapDetected(): void { catalog.refresh(); }
    }
}
