import QtQuick
import Shelllist.Ui as Ui

// Native date counts and repeat keys; only bounded windows are transferred.
Item {
    id: timeline
    required property NotificationState store
    property bool active: false
    property string appKey: ""
    property string query: ""
    property bool grouping: true
    property string requestedDate: ""
    property var snapshot: ({})
    property var entries: []
    property var expandedStacks: ({})
    property bool collapsed: false
    property bool busy: false
    property bool dirty: false
    property string error: ""
    property int generation: 0
    property var staging: []
    property string stagingEpoch: ""
    property string stagingRevision: ""
    property string anchor: ""
    signal viewAboutToChange
    signal viewChanged
    readonly property bool hasMore: snapshot.next_offset !== null && snapshot.next_offset !== undefined
    function invalidate(clear: bool): void {
        generation++; busy = false; dirty = true; staging = [];
        if (clear) { snapshot = ({}); entries = []; expandedStacks = ({}); collapsed = false; }
        if (active) debounce.restart();
    }
    function refresh(): void { dirty = true; if (active) debounce.restart(); }
    function chooseDate(date: string): void {
        if (date === snapshot.date) { collapsed = !collapsed; return; }
        requestedDate = date; collapsed = false;
    }
    function reload(): void {
        if (!active || !appKey || !store.backend.ready || busy) return;
        generation++; dirty = false; error = ""; staging = [];
        stagingEpoch = ""; stagingRevision = "";
        anchor = entries.length ? entries[entries.length - 1].key : "";
        request(0, true);
    }
    function request(offset: int, replacing: bool): void {
        busy = true;
        store.backend.queryCenter({view: "timeline", app_key: appKey, query: query, date: requestedDate || snapshot.date || null,
            group_similar: grouping, offset: offset,
            epoch: offset ? (replacing ? stagingEpoch : snapshot.epoch) : null,
            revision: offset ? (replacing ? stagingRevision : snapshot.revision) : null,
            timeline_anchor: replacing ? anchor || null : null},
            {view: "timeline", generation: generation, appKey: appKey, query: query,
                date: requestedDate, grouping: grouping, offset: offset, replacing: replacing, revision: store.observedHistoryRevision});
    }
    function loadMore(): void {
        if (!active || !store.backend.ready || busy || error || !hasMore) return;
        if (dirty) reload(); else request(snapshot.next_offset, false);
    }
    function valid(value: var, offset: int): bool {
        if (!value || value.view !== "timeline" || value.query !== query || value.app_key !== appKey
            || typeof value.epoch !== "string" || !value.epoch || typeof value.revision !== "string" || !value.revision
            || !Array.isArray(value.dates) || value.dates.length > 5200 || !value.dates.every(d => /^\d{4}-\d{2}-\d{2}$/.test(d.key) && Number.isSafeInteger(d.count) && d.count > 0 && d.count <= 5200)
            || new Set(value.dates.map(d => d.key)).size !== value.dates.length
            || !Number.isSafeInteger(value.total_rows) || value.total_rows < 0 || value.total_rows > 5200
            || !Number.isSafeInteger(value.count) || value.count < 0 || value.count > 5200 || value.total_rows > value.count
            || value.dates.reduce((sum, d) => sum + d.count, 0) > 5200
            || typeof value.anchor_reached !== "boolean" || value.offset !== offset
            || !Array.isArray(value.entries) || value.entries.length > 20) return false;
        if (value.count && !value.dates.some(d => d.key === value.date && d.count === value.count)) return false;
        if (!value.entries.every(e => e.key === Ui.NotificationPresentation.recordKey(e.preview) && e.preview.app_key === appKey
            && typeof e.preview.summary === "string" && typeof e.preview.body === "string" && typeof e.preview.app_name === "string" && typeof e.preview.app_icon === "string"
            && Array.isArray(e.members) && e.members.length > 0 && e.members.length <= 50
            && e.members.every(p => Number.isSafeInteger(p.id) && p.id > 0 && p.id <= 4294967295 && Number.isSafeInteger(p.created) && p.created > 0)
            && e.members[0].id === e.preview.id && e.members[0].created === e.preview.created_unix_ms)) return false;
        const end = offset + value.entries.length;
        return value.next_offset === null ? end === value.total_rows : value.entries.length > 0 && value.next_offset === end && end < value.total_rows;
    }
    function receive(context: var, value: var, failure: string, code: string): void {
        if (context.view !== "timeline" || context.generation !== generation || context.appKey !== appKey || context.query !== query || context.date !== requestedDate || context.grouping !== grouping) return;
        busy = false;
        if (context.revision !== store.observedHistoryRevision || code === "history-cursor-stale") { staging = []; refresh(); return; }
        const base = context.replacing ? staging : entries;
        if (failure || !valid(value, base.length)) { staging = []; error = failure || qsTr("Invalid notification timeline"); return; }
        const epoch = context.replacing ? stagingEpoch : snapshot.epoch;
        const revision = context.replacing ? stagingRevision : snapshot.revision;
        if (context.offset && (epoch !== value.epoch || revision !== value.revision)) { staging = []; refresh(); return; }
        const next = base.concat(value.entries);
        const keys = next.reduce((all, e) => all.concat(e.members.map(p => p.id + ":" + p.created)), []);
        if (new Set(keys).size !== keys.length || keys.length > value.count) { error = qsTr("Notification window did not advance"); staging = []; return; }
        if (context.replacing && value.next_offset !== null && !value.anchor_reached) {
            staging = next; stagingEpoch = value.epoch; stagingRevision = value.revision;
            if (active) request(value.next_offset, true); else invalidate(false);
            return;
        }
        viewAboutToChange();
        if (!store.equal(entries, next)) entries = next;
        snapshot = value; staging = []; error = "";
        viewChanged();
        if (dirty) debounce.restart();
    }
    onRequestedDateChanged: invalidate(true)
    onAppKeyChanged: { requestedDate = ""; invalidate(true); }
    onQueryChanged: { requestedDate = ""; invalidate(true); }
    onGroupingChanged: invalidate(true)
    onActiveChanged: { if (active) refresh(); else { debounce.stop(); invalidate(false); } }
    Timer { id: debounce; interval: 120; onTriggered: if (timeline.dirty) timeline.reload() }
    Connections {
        target: timeline.store
        function onCenterResponse(context: var, value: var, error: string, code: string): void { timeline.receive(context, value, error, code); }
        function onObservedHistoryRevisionChanged(): void { timeline.refresh(); }
        function onCollectionChanged(): void { timeline.invalidate(false); }
        function onDataGenerationChanged(): void { timeline.invalidate(false); timeline.error = qsTr("Notifications unavailable"); }
    }
    Connections {
        target: timeline.store.backend
        function onReadyChanged(): void { if (timeline.store.backend.ready) timeline.refresh(); }
        function onEventGapDetected(): void { timeline.refresh(); }
    }
}
