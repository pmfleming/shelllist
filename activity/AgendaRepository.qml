pragma Singleton
import QtQuick
import Shelllist.Io as Io

// Shared accepted records only. Queries, loaded windows, drafts and selection are
// deliberately owned by each AgendaController. Never replay mutations here.
Item {
    id: repository
    property var records: ({})
    property var recordSizes: ({})
    property var recordOrder: []
    property var owners: ({})
    property var requests: ({})
    property int sequence: 0
    property int epoch: 0
    property int authorityGeneration: -1
    property double catalogRevision: -1
    readonly property bool ready: transport.ready
    signal response(string owner, string purpose, var context, var data, string error)
    signal invalidated
    signal accepted(var item)
    signal removed(string id)
    signal disconnected

    function synchronizeTransportAuthority(): int {
        // Read the actual session object: Core advances this before notifying
        // consumers and only publishes its reactive revision after callbacks.
        const generation = Io.DaemonSessions.sessions["bar-daemon"]?.generation ?? -1;
        if (generation < 0 || generation === authorityGeneration) return generation;
        const previous = authorityGeneration;
        const pending = requests;
        requests = ({});
        authorityGeneration = generation;
        epoch++;
        catalogRevision = -1;
        records = ({}); recordSizes = ({}); recordOrder = [];
        // Controllers retain accepted windows/pinned documents, not authority.
        // Retire old reads and uncertain submitted writes exactly once even if
        // another consumer reached this helper before our failure callback.
        if (previous >= 0) disconnected();
        for (const id of Object.keys(pending)) {
            const request = pending[id];
            response(request.owner, request.purpose, request.context, null, qsTr("Agenda transport changed; previous operation outcome is unconfirmed"));
        }
        return generation;
    }
    function ownerId(): string { return "agenda-owner-" + (++sequence); }
    function setActive(owner: string, active: bool): void {
        if (!owner) return;
        const next = Object.assign({}, owners);
        if (active) next[owner] = true; else delete next[owner];
        owners = next;
    }
    function token(): string { return "agenda-" + Date.now() + "-" + Math.random().toString(36).slice(2) + "-" + (++sequence); }
    function integer(value: var): bool { return Number.isSafeInteger(value) && value >= 0; }
    function text(value: var): bool { return typeof value === "string"; }
    function identity(value: var): bool { return text(value) && value.length > 0 && value.length <= 4096; }
    function uniqueChildren(values: var): bool {
        return Array.isArray(values) && values.length <= 1024 && values.every(value => identity(value?.id)) && new Set(values.map(value => value.id)).size === values.length;
    }
    function validSchedule(schedule: var): bool {
        if (!schedule || !["date", "timed"].includes(schedule.mode)) return false;
        const civil = value => value === null || (text(value) && /^\d{4}-\d\d-\d\d$/.test(value));
        const instant = value => value === null || Number.isSafeInteger(value);
        return civil(schedule.start_date) && civil(schedule.end_date) && instant(schedule.start_unix_ms) && instant(schedule.end_unix_ms)
            && (schedule.timezone === null || text(schedule.timezone))
            && (schedule.mode === "date" ? schedule.start_unix_ms === null && schedule.end_unix_ms === null && schedule.timezone === null : schedule.start_date === null && schedule.end_date === null);
    }
    function validSourceDiagnostics(data: var): bool {
        if (data.failing_source_count === undefined && data.source_error === undefined) return true;
        return integer(data.failing_source_count) && data.failing_source_count <= 2147483647
            && (data.failing_source_count === 0 ? data.source_error === null : text(data.source_error) && data.source_error.length > 0 && data.source_error.length <= 1024);
    }
    // Full documents and summaries share one wire header, not document fields.
    // Keep these shape predicates independent of request/authority ownership.
    function validRecordIdentity(item: var): bool {
        return !!item && identity(item.id) && identity(item.source_id) && (item.source_uid === null || text(item.source_uid))
            && ["event", "task"].includes(item.kind) && integer(item.revision);
    }
    function validCapabilities(capabilities: var): bool {
        return !!capabilities && typeof capabilities.write === "boolean" && typeof capabilities.delete === "boolean" && typeof capabilities.complete === "boolean";
    }
    function validRecordHeader(item: var): bool {
        return validRecordIdentity(item) && text(item.title) && validSchedule(item.schedule)
            && Number.isSafeInteger(item.created_unix_ms) && Number.isSafeInteger(item.modified_unix_ms) && validCapabilities(item.capabilities);
    }
    function validEventSummary(event: var): bool { return !!event && text(event.status) && text(event.location); }
    function validTaskSummary(task: var): bool {
        return !!task && Number.isSafeInteger(task.priority) && text(task.status) && typeof task.completed === "boolean"
            && (task.completed_unix_ms === null || Number.isSafeInteger(task.completed_unix_ms));
    }
    function validSummary(item: var): bool {
        if (item?.summary !== true) return validItem(item);
        return validRecordHeader(item) && (item.kind === "event" ? validEventSummary(item.event) : validTaskSummary(item.task));
    }
    function summaryOf(item: var): var {
        const summary = Object.assign({}, item, {summary: true});
        delete summary.notes; delete summary.links;
        if (summary.event) { summary.event = Object.assign({}, summary.event); delete summary.event.people; }
        if (summary.task) { summary.task = Object.assign({}, summary.task); delete summary.task.checklist; }
        return summary;
    }
    function validDocumentContent(item: var): bool {
        return text(item.notes) && uniqueChildren(item.links) && item.links.every(link => text(link.label) && text(link.url));
    }
    function validEventDocument(item: var): bool {
        return item.task === null && validEventSummary(item.event) && Array.isArray(item.event.people) && item.event.people.every(text);
    }
    function validTaskDocument(item: var): bool {
        return item.event === null && validTaskSummary(item.task) && uniqueChildren(item.task.checklist)
            && item.task.checklist.every(step => text(step.text) && typeof step.checked === "boolean");
    }
    function validItem(item: var): bool {
        return validRecordHeader(item) && item.summary !== true && validDocumentContent(item)
            && (item.kind === "event" ? validEventDocument(item) : validTaskDocument(item));
    }
    function validListPage(data: var, limit: int): bool {
        return !!data && validSourceDiagnostics(data) && Array.isArray(data.items) && data.items.length <= limit && data.items.every(validSummary)
            && integer(data.catalog_revision) && text(data.today) && text(data.timezone) && (data.next_cursor === null || text(data.next_cursor));
    }
    function projection(data: var): var { return {revision: data.catalog_revision, today: data.today, timezone: data.timezone}; }
    function sameProjection(data: var, fence: var): bool {
        return data.catalog_revision === fence.revision && data.today === fence.today && data.timezone === fence.timezone;
    }
    function pageAdvances(values: var, cursor: var, previousCursor: var): bool {
        return new Set(values.map(item => item.id)).size === values.length && (!previousCursor || cursor !== previousCursor);
    }
    function obsoleteSummary(item: var): bool {
        const acceptedItem = records[item.id];
        return !!acceptedItem && (acceptedItem.revision > item.revision || acceptedItem.kind !== item.kind);
    }
    function validMutationResult(draft: var, data: var): bool {
        if (!data || data.request_id !== draft.request_id || !integer(data.catalog_revision)) return false;
        if (draft.kind === "delete") return data.item === null && data.deleted_id === draft.id;
        if (!validItem(data.item)) return false;
        if (draft.kind === "patch") return data.item.id === draft.id && data.item.revision > draft.expected_revision && data.item.kind === draft.recordKind;
        return data.item.kind === draft.item.kind;
    }
    function accept(item: var, revision: var): bool {
        synchronizeTransportAuthority();
        if (!validItem(item) || !integer(revision) || revision < catalogRevision) return false;
        const old = records[item.id];
        if (old && (old.revision > item.revision || old.kind !== item.kind)) return false;
        catalogRevision = revision;
        const next = Object.assign({}, records, {[item.id]: item});
        const sizes = Object.assign({}, recordSizes, {[item.id]: JSON.stringify(item).length * 2});
        const order = recordOrder.filter(id => id !== item.id && !!next[id]).concat([item.id]);
        let bytes = order.reduce((sum, id) => sum + (sizes[id] || 0), 0);
        // Bounded accepted UTF-16 payload cache; controllers retain only their
        // currently inspected full record, not every loaded page's documents.
        while (order.length > 1 && (order.length > 32 || bytes > 8 * 1024 * 1024)) {
            const id = order.shift(); bytes -= sizes[id] || 0; delete next[id]; delete sizes[id];
        }
        recordSizes = sizes; recordOrder = order; records = next;
        accepted(item);
        return true;
    }
    function removeRecord(id: string, revision: var): void {
        synchronizeTransportAuthority();
        if (!identity(id) || !integer(revision)) return;
        catalogRevision = Math.max(catalogRevision, revision);
        const next = Object.assign({}, records); delete next[id]; records = next;
        const sizes = Object.assign({}, recordSizes); delete sizes[id]; recordSizes = sizes;
        recordOrder = recordOrder.filter(key => key !== id);
        removed(id);
    }
    function request(owner: string, purpose: string, method: string, params: var, context: var): string {
        synchronizeTransportAuthority();
        const id = token();
        requests = Object.assign({}, requests, {[id]: {owner: owner, purpose: purpose, context: context, epoch: epoch}});
        transport.call(id, method, params);
        return id;
    }
    function finish(id: string, data: var, error: string): void {
        synchronizeTransportAuthority();
        const request = requests[id];
        if (!request) return;
        const next = Object.assign({}, requests); delete next[id]; requests = next;
        if (request.epoch !== epoch) return;
        response(request.owner, request.purpose, request.context, data, error);
    }
    AgendaTransport {
        id: transport
        active: Object.keys(repository.owners).length > 0 || Object.keys(repository.requests).length > 0
        onCompleted: function(id, data, error) { repository.finish(id, data, error); }
        onTransportFailed: function(message, lostIds) {
            repository.synchronizeTransportAuthority();
            // Usually the helper already consumed these. A reentrant read
            // admitted by another consumer's callback still has one owned
            // failure, without resetting authority a second time.
            for (const id of lostIds) repository.finish(id, null, message);
        }
        onTransportReady: { repository.synchronizeTransportAuthority(); repository.invalidated(); }
        onEventReceived: repository.invalidated()
        onEventGapDetected: repository.invalidated()
    }
}
