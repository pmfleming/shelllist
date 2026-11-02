import QtQuick
import Shelllist.Ui as Ui

// Three newest records and disjoint calendar periods come from the complete
// native catalog; only bounded windows of an explicitly opened period transfer.
Item {
    id: timeline
    required property NotificationState store
    property bool active: false
    property string appKey: ""
    property string query: ""
    property bool grouping: true
    property string requestedDate: ""
    property string localDay: ""
    readonly property var periods: ["today", "week", "month", "older"]
    readonly property int totalCount: (snapshot.recent || []).length + (snapshot.dates || []).reduce((sum, d) => sum + d.count, 0)
    property var snapshot: ({})
    property var entries: []
    property var expandedStacks: ({})
    property bool collapsed: true
    property bool busy: false
    property bool dirty: false
    property string error: ""
    property int generation: 0
    // An unpublished window keeps its accumulated entries and cursor together.
    property var staging: null
    property string anchor: ""
    readonly property int cacheLimit: 200
    readonly property bool cacheFull: entries.length + 20 > cacheLimit
    property int windowOffset: 0
    property int stagingOffset: 0
    property var refreshCursor: null
    property bool restartAtBeginning: false
    property bool readRestarted: false
    property bool resetViewport: false
    signal windowReplaced
    signal viewAboutToChange
    signal viewChanged
    readonly property bool hasMore: snapshot.next_offset !== null && snapshot.next_offset !== undefined
    function invalidate(clear: bool): void {
        generation++; busy = false; staging = null; refreshCursor = null; anchor = "";
        if (clear) { snapshot = ({}); entries = []; expandedStacks = ({}); windowOffset = 0; stagingOffset = 0; error = ""; restartAtBeginning = false; readRestarted = false; }
        refresh();
    }
    function refresh(): void { dirty = true; if (active) debounce.restart(); }
    function chooseDate(date: string): void {
        if (!periods.includes(date) || !(snapshot.dates || []).some(d => d.key === date && d.count > 0)) return;
        viewAboutToChange();
        if (date === requestedDate) collapsed = !collapsed;
        else { requestedDate = date; collapsed = false; }
        viewChanged();
    }
    function reload(): void {
        if (!active || !appKey || !store.backend.ready || busy) return;
        const reset = restartAtBeginning;
        restartAtBeginning = false;
        startRead(reset ? 0 : windowOffset, !reset, reset);
    }
    function startRead(offset: int, preserveExtent: bool, restarted: bool): void {
        generation++; dirty = false; error = ""; staging = null;
        stagingOffset = offset; refreshCursor = snapshot; readRestarted = restarted;
        resetViewport = !preserveExtent || entries.length === 0;
        anchor = preserveExtent && entries.length ? entries[entries.length - 1].key : "";
        request(offset, true);
    }
    function request(offset: int, replacing: bool): void {
        busy = true;
        const cursor = offset ? (replacing ? staging || refreshCursor : snapshot) : null;
        store.backend.queryCenter({view: "timeline", app_key: appKey, query: query, date: requestedDate || null,
            period_groups: true, period_day: cursor?.period_day ?? null,
            group_similar: grouping, offset: offset,
            epoch: cursor?.epoch ?? null, revision: cursor?.revision ?? null,
            timeline_anchor: replacing ? anchor || null : null},
            {view: "timeline", generation: generation, appKey: appKey, query: query,
                date: requestedDate, grouping: grouping, offset: offset, replacing: replacing, revision: store.observedHistoryRevision, restarted: readRestarted});
    }
    function autoLoadMore(): void { if (!cacheFull) loadMore(); }
    function loadMore(): void {
        if (!active || !store.backend.ready || busy || error || !hasMore) return;
        if (dirty) reload();
        else if (cacheFull) startRead(snapshot.next_offset, false, false);
        else request(snapshot.next_offset, false);
    }
    function showRecent(): void {
        if (active && store.backend.ready && !busy) startRead(0, false, false);
    }
    function staleRead(context: var): void {
        if (context.restarted) { error = qsTr("Notification history changed; refresh again"); return; }
        restartAtBeginning = true;
        refresh();
    }
    function validPreview(item: var): bool {
        return NotificationValidation.preview(item) && item.app_key === appKey;
    }
    function validPeriods(dates: var): bool {
        return Array.isArray(dates) && dates.length === periods.length
            && dates.every((d, i) => d?.key === periods[i] && NotificationValidation.integerIn(d.count, 0, 5200));
    }
    function validEntry(entry: var): bool {
        return !!entry && validPreview(entry.preview) && entry.key === Ui.NotificationPresentation.recordKey(entry.preview)
            && Array.isArray(entry.members) && NotificationValidation.integerIn(entry.members.length, 1, 50)
            && entry.members.every(p => !!p && NotificationValidation.identity(p.id, p.created))
            && entry.members[0].id === entry.preview.id && entry.members[0].created === entry.preview.created_unix_ms;
    }
    function valid(value: var, offset: int): bool {
        if (!NotificationValidation.envelope(value, "timeline", query) || value.app_key !== appKey
            || !/^\d{4}-\d{2}-\d{2}$/.test(value.period_day) || value.date !== requestedDate
            || !Array.isArray(value.recent) || value.recent.length > 3 || !value.recent.every(validPreview)
            || !validPeriods(value.dates) || !NotificationValidation.integerIn(value.count, 0, 5200)
            || !NotificationValidation.integerIn(value.total_rows, 0, value.count)
            || value.dates.reduce((sum, d) => sum + d.count, value.recent.length) > 5200
            || !Array.isArray(value.entries) || value.entries.length > 20 || !value.entries.every(validEntry)) return false;
        if (value.date ? !value.dates.some(d => d.key === value.date && d.count === value.count) : value.count !== 0) return false;
        return NotificationValidation.pageEnds(value, offset, value.entries.length, value.total_rows);
    }
    function ownsRead(context: var): bool {
        return context.view === "timeline" && context.generation === generation && context.appKey === appKey
            && context.query === query && context.date === requestedDate && context.grouping === grouping;
    }
    function sameWindow(previous: var, value: var): bool {
        return !!previous && previous.epoch === value.epoch && previous.revision === value.revision
            && previous.period_day === value.period_day && previous.date === value.date
            && store.equal(previous.recent, value.recent) && store.equal(previous.dates, value.dates);
    }
    function receive(context: var, value: var, failure: string, code: string): void {
        if (!active || !ownsRead(context)) return;
        busy = false;
        const previous = context.replacing ? staging || refreshCursor : snapshot;
        const base = context.replacing ? staging?.entries ?? [] : entries;
        // Consume unpublished state once. Only a valid continuation installs it
        // again; every rejection leaves both its rows and cursor discarded.
        staging = null;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") { staleRead(context); return; }
        if (failure || !valid(value, (context.replacing ? stagingOffset : windowOffset) + base.length)) { error = failure || qsTr("Invalid notification timeline"); return; }
        if (context.offset && !sameWindow(previous, value)) { staleRead(context); return; }
        const next = base.concat(value.entries);
        const keys = [];
        next.forEach(e => e.members.forEach(p => keys.push(p.id + ":" + p.created)));
        const allKeys = keys.concat(value.recent.map(p => Ui.NotificationPresentation.recordKey(p)));
        if (new Set(allKeys).size !== allKeys.length || keys.length > value.count || next.length > cacheLimit) { error = qsTr("Notification window did not advance"); return; }
        acceptWindow(context.replacing, value, next);
    }
    function acceptWindow(replacing: bool, value: var, next: var): void {
        if (replacing && value.next_offset !== null && !value.anchor_reached && next.length + 20 <= cacheLimit) {
            staging = Object.assign({}, value, {entries: next});
            if (active) request(value.next_offset, true); else invalidate(false);
            return;
        }
        viewAboutToChange();
        if (replacing) {
            windowOffset = stagingOffset;
            const retained = {};
            next.forEach(entry => { if (expandedStacks[entry.key]) retained[entry.key] = true; });
            expandedStacks = retained;
        }
        if (!store.equal(entries, next)) entries = next;
        snapshot = value; error = ""; anchor = ""; refreshCursor = null; readRestarted = false;
        if (replacing && resetViewport) windowReplaced();
        viewChanged();
        if (dirty) debounce.restart();
    }
    onRequestedDateChanged: { invalidate(false); entries = []; expandedStacks = ({}); windowOffset = 0; stagingOffset = 0; snapshot = Object.assign({}, snapshot, {next_offset: null}); }
    onLocalDayChanged: refresh()
    onAppKeyChanged: { requestedDate = ""; invalidate(true); }
    onQueryChanged: { requestedDate = ""; invalidate(true); }
    onGroupingChanged: invalidate(true)
    onActiveChanged: { if (active) refresh(); else { debounce.stop(); invalidate(true); } }
    Timer { id: debounce; interval: 120; onTriggered: if (timeline.dirty) timeline.reload() }
    Connections {
        target: timeline.store
        function onCenterResponse(context: var, value: var, error: string, code: string): void { timeline.receive(context, value, error, code); }
        function onObservedHistoryRevisionChanged(): void { timeline.refresh(); }
        function onCollectionChanged(): void { timeline.invalidate(false); }
        function onDataGenerationChanged(): void { timeline.invalidate(true); timeline.error = qsTr("Notifications unavailable"); }
    }
    Connections {
        target: timeline.store.backend
        function onReadyChanged(): void { if (timeline.store.backend.ready) timeline.refresh(); }
        function onEventGapDetected(): void { timeline.refresh(); }
    }
}
