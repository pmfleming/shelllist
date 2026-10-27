import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as ActivityApi

// Accepted presentation survives disconnects; only the transport authority below
// can decide whether a reply may replace it. Selection/fit stay in the host.
Io.DaemonBackend {
    id: reader
    required property string fromDate
    required property string toDate
    readonly property string rangeKey: fromDate + "/" + toDate
    readonly property int authorityGeneration: authority.generation
    property var days: ({})
    property real catalogRevision: -1
    property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string timezone: ""
    property int failingSourceCount: 0
    property string sourceError: ""
    property string error: ""
    property string latestRead: ""
    property string latestRange: ""

    daemonName: "bar-daemon"
    expectedProtocol: ActivityApi.protocol
    expectedVersion: ActivityApi.version
    streams: [ActivityApi.streams.activity, ActivityApi.streams.timezone]

    QtObject {
        id: authority
        property int generation: -1
        property real revision: -1
        property int staleRetriesRemaining: 1
        property bool paused: false
    }
    function currentGeneration(): int {
        // failSession advances this before notifying consumers/revision bindings.
        const session = Io.DaemonSessions.sessions[daemonName];
        return session ? session.generation : -1;
    }
    function synchronizeAuthority(): void {
        const generation = AgendaRepository.synchronizeTransportAuthority();
        if (authority.generation === generation) return;
        latestRead = "";
        authority.generation = generation;
        authority.revision = -1;
        authority.staleRetriesRemaining = 1;
        authority.paused = false;
    }
    // External invalidation/explicit refresh starts a bounded read episode, but
    // activation within one transport never forgets an accepted revision floor.
    function refresh(): void {
        if (!active) return;
        synchronizeAuthority();
        authority.staleRetriesRemaining = 1;
        authority.paused = false;
        schedule();
    }
    function schedule(): void {
        if (!active || authority.paused) return;
        latestRead = ""; // Fence before debounce, including same-range invalidation.
        debounce.restart();
    }
    function poll(): void {
        if (!authority.paused && !latestRead.length) schedule();
    }
    function pause(message: string): void {
        latestRead = "";
        authority.paused = true;
        debounce.stop();
        error = message;
    }
    function read(): void {
        if (!active || !ready || authority.paused) return;
        synchronizeAuthority();
        latestRead = nextRequestId("agenda-markers");
        latestRange = rangeKey;
        call(latestRead, "agenda.markers", {from_date: fromDate, to_date: toDate});
    }
    function ownsRead(id: string): bool {
        return id.length > 0 && id === latestRead && active && latestRange === rangeKey
            && authority.generation === currentGeneration();
    }
    function validDate(key: var): bool {
        if (typeof key !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(key)) return false;
        const value = new Date(key + "T12:00:00Z");
        return Number.isFinite(value.getTime()) && value.toISOString().slice(0, 10) === key;
    }
    function validMetadata(data: var): bool {
        return !!data && Array.isArray(data.days) && data.days.length <= 370
            && Number.isSafeInteger(data.catalog_revision) && data.catalog_revision >= 0
            && validDate(data.today) && typeof data.timezone === "string" && data.timezone.length > 0;
    }
    function validDiagnostics(data: var): bool {
        if (data.failing_source_count === undefined && data.source_error === undefined) return true;
        if (!Number.isSafeInteger(data.failing_source_count) || data.failing_source_count < 0 || data.failing_source_count > 2147483647) return false;
        return data.failing_source_count === 0 ? data.source_error === null
            : typeof data.source_error === "string" && data.source_error.length > 0 && data.source_error.length <= 1024;
    }
    function validDay(day: var, seen: var): bool {
        return !!day && validDate(day.date) && day.date >= fromDate && day.date <= toDate
            && typeof day.event === "boolean" && typeof day.task === "boolean" && !seen[day.date];
    }
    // Decode into an unpublished window: no rejected suffix can publish a prefix.
    function validatedDays(data: var): var {
        if (!validMetadata(data) || !validDiagnostics(data)) return null;
        const next = {};
        for (const day of data.days) {
            if (!validDay(day, next)) return null;
            next[day.date] = {event: day.event, task: day.task};
        }
        return next;
    }
    function staleRevision(revision: real): bool {
        const sharedFloor = AgendaRepository.authorityGeneration === authority.generation ? AgendaRepository.catalogRevision : -1;
        return revision < Math.max(authority.revision, sharedFloor);
    }
    function rejectStale(): void {
        error = qsTr("Calendar window is stale; refresh to try again");
        if (authority.staleRetriesRemaining > 0) {
            authority.staleRetriesRemaining--;
            schedule();
        } else pause(error);
    }
    function accept(id: string, data: var, failure: string): bool {
        if (!ownsRead(id)) return false;
        latestRead = "";
        if (failure) { pause(failure); return false; }
        const next = validatedDays(data);
        if (next === null) { pause(qsTr("Invalid calendar marker window")); return false; }
        if (staleRevision(data.catalog_revision)) { rejectStale(); return false; }
        days = next;
        catalogRevision = data.catalog_revision;
        authority.revision = data.catalog_revision;
        AgendaRepository.catalogRevision = Math.max(AgendaRepository.catalogRevision, catalogRevision);
        today = data.today;
        timezone = data.timezone;
        failingSourceCount = data.failing_source_count ?? 0;
        sourceError = data.source_error ?? "";
        authority.paused = false;
        authority.staleRetriesRemaining = 1;
        error = "";
        return true;
    }
    onFromDateChanged: refresh()
    onToDateChanged: refresh()
    onActiveChanged: {
        if (active) refresh();
        else { latestRead = ""; debounce.stop(); }
    }
    onTransportReady: refresh()
    onEventReceived: refresh()
    onEventGapDetected: refresh()
    onResponseReceived: function(id, envelope, transportError) {
        accept(id, envelope?.data, responseError(envelope, transportError, qsTr("Calendar read failed")));
    }
    onSendFailed: function(id, message) { accept(id, null, message); }
    onTransportFailed: function(message) { synchronizeAuthority(); pause(message); }
    Connections {
        target: AgendaRepository
        function onInvalidated(): void { reader.refresh(); }
    }
    Timer { id: debounce; interval: 30; onTriggered: reader.read() }
    // Poll only healthy/idle readers; a rejected episode waits for real input.
    Timer { interval: 60000; repeat: true; running: reader.active; onTriggered: reader.poll() }
}
