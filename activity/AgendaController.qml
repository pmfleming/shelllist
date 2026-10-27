import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Ui.ChooserController {
    id: controller
    property string ownerId: ""
    property string dayScope: ""
    property string filterText: ""
    property string detailsTab: "details"
    property var items: []
    readonly property alias itemModel: rows
    property var creationResult: null
    readonly property var selectedSummary: creationResult || (publishing ? selectionDuringPublish : items[selection.selectedIndex]) || null
    property var selectionDuringPublish: null
    property var detailItem: null
    property int detailEpoch: -1
    onDetailItemChanged: detailEpoch = AgendaRepository.epoch
    readonly property var selectedItem: selectedSummary && detailItem?.id === selectedSummary.id ? detailItem : selectedSummary && AgendaRepository.records[selectedSummary.id]?.revision >= selectedSummary.revision ? AgendaRepository.records[selectedSummary.id] : selectedSummary
    property bool detailLoading: false
    property string detailError: ""
    property int detailGeneration: 0
    property int selectionSerial: 0
    onSelectedSummaryChanged: {
        const cached = selectedSummary ? AgendaRepository.records[selectedSummary.id] : null;
        if (cached && detailItem?.id !== selectedSummary.id && cached.revision >= selectedSummary.revision) detailItem = cached;
        if (detailsOpen) requestSelected();
    }
    onDetailsOpenChanged: if (detailsOpen) requestSelected()
    property string retainedId: ""
    property bool publishing: false
    property bool loading: false
    property bool acceptedWindow: false
    property string error: ""
    property int failingSourceCount: 0
    property string sourceError: ""
    property string nextCursor: ""
    property double windowRevision: -1
    property string windowToday: ""
    property string windowTimezone: ""
    property int windowEpoch: -1
    property string acceptedQuery: ""
    property string acceptedDay: ""
    property int readGeneration: 0
    property bool settingsOpen: false
    property bool collectionOpen: false
    property string collectionKey: ""
    property string collectionText: ""
    property string collectionUrl: ""
    property string collectionEntryId: ""
    property var collectionTarget: null
    property bool createOpen: false
    property var createDraft: ({kind: "task", title: "", schedule: emptySchedule()})
    property var deleteTarget: null
    property bool scheduleOpen: false
    property var scheduleTarget: null
    property var scheduleDraft: emptySchedule()
    property var scheduleText: null
    property var scheduleRaw: null
    property var createScheduleRaw: null
    property var pendingSchedule: null
    readonly property bool scheduleParsing: pendingSchedule !== null
    onCreateOpenChanged: if (!createOpen && pendingSchedule?.purpose === "create") pendingSchedule = null
    onScheduleOpenChanged: if (!scheduleOpen && pendingSchedule?.purpose === "schedule") pendingSchedule = null
    // Only explicitly saved/submitted drafts live here, never native buffers.
    property var savedDrafts: ({})
    property var operation: null
    property var failedOperation: null
    property bool receiptBusy: false
    property var rebaseTarget: null
    readonly property bool mutationBusy: operation !== null
    readonly property bool modalOpen: createOpen || deleteTarget !== null || scheduleOpen || settingsOpen || collectionOpen || rebaseTarget !== null
    readonly property var failedDraft: Object.values(savedDrafts).find(draft => draft.id === selectedItem?.id) || null
    geometry.horizontalOverflowAllowed: false
    navigationBlocked: modalOpen
    actionInFlight: mutationBusy
    hasSelection: selectedItem !== null
    selectionModel: selection
    viewMemory: Ui.ChooserMemory {
        controller: controller
        key: controller.selectedItem ? "agenda::" + controller.selectedItem.id : ""
        tab: controller.detailsTab
        tabs: ["details", "notes", "information"]
        onRestoreRequested: function(open, tab) { controller.detailsTab = tab; }
    }
    detailActions: [
        {id: "complete", label: selectedItem?.task?.completed ? qsTr("Reopen task") : qsTr("Complete task"), icon: selectedItem?.task?.completed ? "restore" : "check", accessKey: "C", enabled: canComplete(selectedItem), presentation: {group: selectedItem?.kind === "task" ? "primary" : "toolbar"}},
        {id: "schedule", label: qsTr("Edit schedule"), icon: "today", accessKey: "E", enabled: canWrite(selectedItem), presentation: {group: "toolbar"}},
        {id: "delete", label: qsTr("Delete item"), icon: "delete", accessKey: "D", enabled: !!selectedItem?.capabilities.delete && !mutationBusy, presentation: {group: "toolbar", tone: "danger"}},
        {id: "retry", label: qsTr("Retry saved draft"), icon: "refresh", accessKey: "R", enabled: !!failedDraft && !mutationBusy, presentation: {group: "toolbar"}},
        {id: "receipt", label: qsTr("Check saved operation outcome"), icon: "find_in_page", accessKey: "K", enabled: !!failedOperation && !mutationBusy && !receiptBusy, presentation: {group: "toolbar"}}
    ].filter(action => action.id !== "complete" || selectedItem?.kind === "task")

    function emptySchedule(): var { return {mode: "date", start_date: null, end_date: null, start_unix_ms: null, end_unix_ms: null, timezone: null}; }
    function copy(value: var): var { return JSON.parse(JSON.stringify(value)); }
    function canWrite(item: var): bool { return !!item?.capabilities.write && item.summary !== true && !mutationBusy && AgendaRepository.ready; }
    function canComplete(item: var): bool { return item?.kind === "task" && !!item.capabilities.complete && !mutationBusy && AgendaRepository.ready; }
    function resultKeyAt(index: int): string { return items[index]?.id || ""; }
    function resultIndexForKey(key: string): int { return items.findIndex(item => item.id === key); }
    function setDetailsTab(tab: string): void { if (["details", "notes", "information"].includes(tab)) detailsTab = tab; }
    function cycleDetailsTab(backwards: bool): void { detailsTab = tabAfter(["details", "notes", "information"], detailsTab, backwards); }
    function select(index): void {
        if (index < 0 || index >= items.length) return;
        if ((selectedSummary?.id || "") !== (items[index]?.id || "")) detailsClosing();
        creationResult = null; selection.selectedIndex = index;
    }
    function selectFirst(): void { select(0); }
    function moveSelection(delta): void { select(selection.clampIndex(selection.selectedIndex + delta)); }
    function openDetails(): void {
        if (creationResult && items.length) { creationResult = null; selection.selectedIndex = Math.max(0, selection.selectedIndex); }
        if (viewMemory) viewMemory.synchronize();
        if (hasSelection) detailsOpen = true;
    }
    function primarySelected(): bool {
        if (!items.length || modalOpen) return false;
        if (creationResult && items.length) { creationResult = null; selection.selectedIndex = Math.max(0, selection.selectedIndex); }
        if (!selectedItem || modalOpen) return false;
        if (selectedItem.kind === "task") { complete(selectedItem); return true; }
        openDetails(); return true;
    }
    function requestSelected(): void {
        if (selectedSummary && (selectedItem?.summary === true || detailEpoch !== AgendaRepository.epoch)) requestItem(selectedSummary, false);
        else if (selectedSummary && selectedItem?.revision < selectedSummary.revision) requestItem(selectedSummary, false);
    }
    function requestItem(item: var, completeAfter: bool, reviewDraft: var): void {
        AgendaRepository.synchronizeTransportAuthority();
        if (!uiActive || !AgendaRepository.ready) return;
        detailGeneration++; detailLoading = true; detailError = "";
        AgendaRepository.request(ownerId, "get", "agenda.get", {id: item.id}, {id: item.id, recordKind: item.kind, revision: item.revision, generation: detailGeneration,
            completeAfter: completeAfter, reviewDraft: reviewDraft, selectionSerial: selectionSerial, readGeneration: readGeneration});
    }
    function receiveItem(context: var, data: var, message: string): void {
        if (context.generation !== detailGeneration || !uiActive) return;
        detailLoading = false;
        if (message || !AgendaRepository.validItem(data?.item) || data.item.id !== context.id || data.item.kind !== context.recordKind || data.item.revision < context.revision
            || !AgendaRepository.integer(data.catalog_revision) || data.catalog_revision < AgendaRepository.catalogRevision
            || AgendaRepository.records[context.id]?.revision > data.item.revision || items.find(item => item.id === context.id)?.revision > data.item.revision) {
            detailError = message || qsTr("Invalid or obsolete agenda details");
            if (context.completeAfter) error = detailError;
            if (detailsOpen && selectedSummary?.id !== context.id) requestSelected();
            return;
        }
        if (selectedSummary?.id === context.id) detailItem = data.item;
        AgendaRepository.accept(data.item, data.catalog_revision);
        if (context.reviewDraft && context.selectionSerial === selectionSerial) rebaseTarget = {draft: context.reviewDraft, item: data.item};
        if (context.completeAfter && context.selectionSerial === selectionSerial && context.readGeneration === readGeneration) {
            // Accept fresh inspection data, but never rebase the captured action.
            if (data.item.revision !== context.revision) error = qsTr("Agenda item changed; review before trying again");
            else complete(data.item);
        }
        if (detailsOpen && selectedSummary?.id !== context.id) requestSelected();
    }
    function complete(item: var): void {
        if (!canComplete(item)) return;
        if (item.summary === true) {
            const full = AgendaRepository.records[item.id];
            if (full && full.revision > item.revision) {
                if (selectedSummary?.id === item.id) detailItem = full;
                error = qsTr("Agenda item changed; review before trying again");
            } else if (full && full.revision === item.revision) complete(full);
            else requestItem(item, true);
            return;
        }
        const task = Object.assign({}, item.task, {completed: !item.task.completed, completed_unix_ms: null});
        savePatch(item, "task.completed", {task: task}, !item.task.completed);
    }
    function triggerDetailAction(action: string): void {
        if (modalOpen) return;
        if (action === "complete") complete(selectedItem);
        else if (action === "schedule" && canWrite(selectedItem)) {
            scheduleTarget = selectedItem;
            scheduleDraft = copy(valueFor(selectedItem, "schedule", selectedItem.schedule));
            scheduleText = JSON.stringify(scheduleDraft) === JSON.stringify(selectedItem.schedule) ? selectedItem.schedule_text || null : null; scheduleRaw = null;
            scheduleOpen = true;
        } else if (action === "delete" && selectedItem?.capabilities.delete && !mutationBusy) deleteTarget = selectedItem;
        else if (action === "retry" && failedDraft && !mutationBusy) requestItem(selectedSummary, false, copy(failedDraft));
        else if (action === "receipt") checkReceipt();
    }
    function valueFor(item: var, key: string, fallback: var): var {
        return savedDrafts[item?.id + ":" + key]?.value ?? fallback;
    }
    // Immediate switches/commands have one begin/save boundary. Deferred native
    // editors must use AgendaInlineEdit and pass its immutable begin snapshot.
    function saveField(key: string, value: var): void { saveFieldFor(selectedItem, key, value); }
    function saveFieldFor(item: var, key: string, value: var): void {
        if (!canWrite(item)) return;
        const parts = key.split(".");
        let patch = {};
        if (parts.length === 1) patch[key] = value;
        else patch[parts[0]] = Object.assign({}, item[parts[0]], {[parts[1]]: value});
        savePatch(item, key, patch, value);
    }
    function savePatch(item: var, key: string, patch: var, value: var): void {
        if (!item || mutationBusy) return;
        const draft = {kind: "patch", recordKind: item.kind, id: item.id, expected_revision: item.revision, baseline: copy(item), key: key,
            patch: copy(patch), value: value === undefined ? copy(patch) : copy(value), request_id: AgendaRepository.token()};
        savedDrafts = Object.assign({}, savedDrafts, {[item.id + ":" + key]: draft});
        submit(draft);
    }
    function submit(draft: var): void {
        AgendaRepository.synchronizeTransportAuthority();
        if (mutationBusy || !AgendaRepository.ready) return;
        operation = draft; error = "";
        const params = {request_id: draft.request_id};
        if (draft.kind === "create") params.item = draft.item;
        else { params.id = draft.id; params.expected_revision = draft.expected_revision; if (draft.kind === "patch") params.patch = draft.patch; }
        AgendaRepository.request(ownerId, "mutation", "agenda." + draft.kind, params, draft);
    }
    function openCreation(): void {
        if (modalOpen || mutationBusy) return;
        if (failedOperation?.kind === "create") {
            createDraft = copy(failedOperation.item); createScheduleRaw = null; createOpen = true; return;
        }
        const schedule = emptySchedule(); schedule.start_date = dayScope || null; schedule.end_date = dayScope || null;
        createDraft = {kind: "task", title: "", schedule: schedule}; createScheduleRaw = null; createOpen = true; error = "";
    }
    function create(): void {
        if (!createOpen || mutationBusy) return;
        if (!createDraft.title.trim()) { error = qsTr("Title is required"); return; }
        if (scheduleParsing) return;
        if (createScheduleRaw) { parseSchedule("create", createScheduleRaw); return; }
        submitCreation(createDraft);
    }
    function saveSchedule(): void {
        if (!scheduleOpen || !canWrite(scheduleTarget)) return;
        if (scheduleParsing) return;
        if (scheduleRaw) { parseSchedule("schedule", scheduleRaw); return; }
        savePatch(scheduleTarget, "schedule", {schedule: scheduleDraft}, scheduleDraft);
    }
    function submitCreation(item: var): void {
        const previous = failedOperation?.kind === "create" && JSON.stringify(failedOperation.item) === JSON.stringify(item) ? failedOperation : null;
        submit(previous || {kind: "create", request_id: AgendaRepository.token(), item: copy(item)});
    }
    function parseSchedule(purpose: string, raw: var): void {
        AgendaRepository.synchronizeTransportAuthority();
        const base = copy(purpose === "create" ? createDraft.schedule : scheduleDraft);
        const preserve = base.mode === "timed" && raw.mode === "timed";
        const context = {token: AgendaRepository.token(), purpose: purpose, item: copy(createDraft), target: scheduleTarget, base: base, raw: copy(raw)};
        // Existing endpoints are already accepted instants, not newly entered
        // wall times. Keep those facts exactly; validate only changed raw timed
        // text, then let the mutation validate the complete compound range.
        const params = {mode: raw.mode, start_text: preserve && raw.start_unchanged ? "" : raw.start_text,
            end_text: preserve && raw.end_unchanged ? "" : raw.end_text, timezone: raw.timezone};
        pendingSchedule = context; error = "";
        AgendaRepository.request(ownerId, "schedule", "agenda.schedule", params, context);
    }
    function receiveSchedule(context: var, data: var, message: string): void {
        if (pendingSchedule?.token !== context.token) return;
        pendingSchedule = null;
        if (message || !AgendaRepository.validSchedule(data?.schedule) || data.schedule.mode !== context.raw.mode
            || (context.raw.mode === "timed" && data.schedule.timezone !== context.raw.timezone)) { error = message || qsTr("Invalid schedule response"); return; }
        const schedule = copy(data.schedule);
        if (context.base.mode === "timed" && context.raw.mode === "timed") {
            if (context.raw.start_unchanged) schedule.start_unix_ms = context.base.start_unix_ms;
            if (context.raw.end_unchanged) schedule.end_unix_ms = context.base.end_unix_ms;
        }
        if (context.purpose === "create" && createOpen && JSON.stringify(context.item) === JSON.stringify(createDraft)) {
            createDraft = Object.assign({}, context.item, {schedule: schedule});
            submitCreation(createDraft);
        } else if (context.purpose === "schedule" && scheduleOpen && scheduleTarget?.id === context.target?.id) {
            scheduleDraft = schedule;
            savePatch(context.target, "schedule", {schedule: schedule}, schedule);
        }
    }
    function confirmDelete(): void {
        if (!deleteTarget?.capabilities.delete || mutationBusy) return;
        submit(failedOperation?.kind === "delete" && failedOperation.id === deleteTarget.id && failedOperation.expected_revision === deleteTarget.revision ? failedOperation : {kind: "delete", recordKind: deleteTarget.kind, id: deleteTarget.id, expected_revision: deleteTarget.revision, request_id: AgendaRepository.token()});
    }
    function openCollection(key: string): void {
        if (!canWrite(selectedItem) || modalOpen) return;
        collectionTarget = selectedItem; collectionKey = key; collectionEntryId = AgendaRepository.token();
        collectionText = ""; collectionUrl = ""; collectionOpen = true;
    }
    function addCollection(): void {
        if (!collectionOpen || !canWrite(collectionTarget) || !collectionText.trim()) return;
        const values = copy(valueFor(collectionTarget, collectionKey, collectionKey === "links" ? collectionTarget.links : collectionTarget.task.checklist));
        const entry = collectionKey === "links" ? {id: collectionEntryId, label: collectionText, url: collectionUrl} : {id: collectionEntryId, text: collectionText, checked: false};
        const index = values.findIndex(value => value.id === collectionEntryId);
        if (index >= 0) values[index] = entry; else values.push(entry);
        const patch = collectionKey === "links" ? {links: values} : {task: Object.assign({}, collectionTarget.task, {checklist: values})};
        savePatch(collectionTarget, collectionKey, patch, values);
    }
    function closeModals(): void { pendingSchedule = null; createOpen = false; scheduleOpen = false; deleteTarget = null; settingsOpen = false; collectionOpen = false; rebaseTarget = null; }
    function refresh(): void {
        readGeneration++; loading = false; debounce.restart();
    }
    function readPage(append: bool): void {
        AgendaRepository.synchronizeTransportAuthority();
        if (!uiActive || !AgendaRepository.ready || loading || (append && !nextCursor)) return;
        if (append && windowEpoch !== AgendaRepository.epoch) append = false;
        requestPage(append, append ? nextCursor : "", [], null);
    }
    function requestPage(append: bool, cursor: string, staging: var, fence: var): void {
        AgendaRepository.synchronizeTransportAuthority();
        loading = true;
        AgendaRepository.request(ownerId, "list", "agenda.list", {query: filterText, day: dayScope || null, cursor: cursor || null, limit: 50},
            {generation: readGeneration, query: filterText, day: dayScope, append: append, cursor: cursor, staging: staging, epoch: AgendaRepository.epoch,
                fence: fence});
    }
    function loadMore(): void { if (!error) readPage(true); }
    function publish(values: var): void {
        const id = creationResult?.id || retainedId;
        const previousId = selectedSummary?.id || "";
        const index = values.findIndex(item => item.id === id);
        const nextIndex = index >= 0 ? index : creationResult ? -1 : Math.max(0, Math.min(selection.selectedIndex, values.length - 1));
        const nextId = creationResult && index < 0 ? creationResult.id : values[nextIndex]?.id || "";
        if (nextId !== previousId) detailsClosing();
        resultsAboutToChange(true);
        selectionDuringPublish = selectedSummary; publishing = true;
        items = values;
        rows.values = values.map(item => ({key: item.id, payload: item}));
        selection.selectedIndex = nextIndex;
        if (creationResult && index >= 0) creationResult = null;
        retainedId = values[selection.selectedIndex]?.id || "";
        publishing = false; selectionDuringPublish = null;
        if ((selectedSummary?.id || "") !== previousId) selectionSerial++;
        resultsChanged();
        if (!selectedItem) closeDetails();
    }
    function ownsListRead(context: var): bool {
        return context.generation === readGeneration && context.query === filterText && context.day === dayScope
            && context.epoch === AgendaRepository.epoch && uiActive;
    }
    function staleListProjection(context: var, data: var): bool {
        if (data.catalog_revision < AgendaRepository.catalogRevision) return true;
        if (context.append && !AgendaRepository.sameProjection(data, {revision: windowRevision, today: windowToday, timezone: windowTimezone})) return true;
        return !!context.fence && !AgendaRepository.sameProjection(data, context.fence);
    }
    function refreshNeedsContinuation(context: var, count: int, cursor: var): bool {
        return !context.append && acceptedWindow && acceptedQuery === filterText && acceptedDay === dayScope && count < items.length && !!cursor;
    }
    function acceptListWindow(data: var, values: var): void {
        values.filter(item => item.summary !== true).forEach(item => AgendaRepository.accept(item, data.catalog_revision));
        AgendaRepository.catalogRevision = data.catalog_revision;
        windowRevision = data.catalog_revision; windowToday = data.today; windowTimezone = data.timezone; windowEpoch = AgendaRepository.epoch;
        nextCursor = data.next_cursor || ""; acceptedWindow = true; acceptedQuery = filterText; acceptedDay = dayScope; error = "";
        failingSourceCount = data.failing_source_count || 0; sourceError = data.source_error || "";
        publish(values.map(AgendaRepository.summaryOf));
    }
    function receiveList(context: var, data: var, message: string): void {
        AgendaRepository.synchronizeTransportAuthority();
        if (!ownsListRead(context)) return;
        loading = false;
        if (message) { error = message; return; }
        if (!AgendaRepository.validListPage(data, 50)) { error = qsTr("Invalid agenda window"); return; }
        if (staleListProjection(context, data)) { refresh(); return; }
        const values = context.append ? items.concat(data.items) : (context.staging || []).concat(data.items);
        if (!AgendaRepository.pageAdvances(values, data.next_cursor, context.cursor)) { error = qsTr("Agenda page did not advance"); return; }
        if (data.items.some(AgendaRepository.obsoleteSummary)) { error = qsTr("Obsolete agenda record revision"); return; }
        // Only the final, fully validated replacement publishes records/metadata.
        // Partial refresh failures retain the accepted selection/editor window.
        if (refreshNeedsContinuation(context, values.length, data.next_cursor)) {
            requestPage(false, data.next_cursor, values, AgendaRepository.projection(data)); return;
        }
        acceptListWindow(data, values);
    }
    function confirmRebase(): void {
        if (!rebaseTarget || mutationBusy) return;
        const draft = copy(rebaseTarget.draft);
        const item = rebaseTarget.item;
        if (!(draft.key === "task.completed" ? canComplete(item) : canWrite(item))) { error = qsTr("The current item no longer permits this change"); return; }
        if (AgendaRepository.records[item.id]?.revision > item.revision) { error = qsTr("Item changed again. Review the latest revision before retry."); rebaseTarget = null; return; }
        const parts = draft.key.split(".");
        draft.expected_revision = item.revision;
        draft.baseline = copy(item);
        draft.request_id = AgendaRepository.token();
        if (parts.length > 1) draft.patch[parts[0]] = Object.assign({}, item[parts[0]], {[parts[1]]: draft.value});
        if (draft.key === "task.completed") draft.patch.task.completed_unix_ms = null;
        savedDrafts = Object.assign({}, savedDrafts, {[draft.id + ":" + draft.key]: draft});
        rebaseTarget = null;
        submit(draft);
    }
    function checkReceipt(): void {
        AgendaRepository.synchronizeTransportAuthority();
        if (!failedOperation || receiptBusy || mutationBusy || !AgendaRepository.ready) return;
        receiptBusy = true;
        AgendaRepository.request(ownerId, "receipt", "agenda.receipt", {request_id: failedOperation.request_id}, failedOperation);
    }
    function receiveReceipt(draft: var, data: var, message: string): void {
        receiptBusy = false;
        if (!failedOperation || failedOperation.request_id !== draft.request_id) return;
        if (message || !data?.receipt) { error = message || qsTr("No committed receipt found. Draft retained for explicit retry."); return; }
        if (operation) { error = qsTr("Another change is pending. Check the previous outcome again after it finishes."); return; }
        operation = draft;
        receiveMutation(draft, data.receipt, "");
    }
    function clearsFailedOperation(draft: var): bool {
        return failedOperation?.request_id === draft.request_id
            || (draft.kind === "patch" && failedOperation?.id === draft.id && failedOperation?.key === draft.key);
    }
    function publishMutation(draft: var, data: var): void {
        if (draft.kind === "delete") { AgendaRepository.removeRecord(draft.id, data.catalog_revision); deleteTarget = null; }
        else {
            AgendaRepository.accept(data.item, data.catalog_revision);
            if (draft.kind === "create") {
                publishing = true; selection.selectedIndex = -1; publishing = false;
                creationResult = data.item; createOpen = false; detailsOpen = true;
            }
            if (draft.key === "schedule") scheduleOpen = false;
            if (collectionOpen && collectionTarget?.id === draft.id && collectionKey === draft.key) collectionOpen = false;
            const next = Object.assign({}, savedDrafts); delete next[draft.id + ":" + draft.key]; savedDrafts = next;
        }
        AgendaRepository.invalidated();
    }
    function receiveMutation(draft: var, data: var, message: string): void {
        if (!operation || operation.request_id !== draft.request_id) return;
        operation = null;
        if (!message && !AgendaRepository.validMutationResult(draft, data)) message = qsTr("Unconfirmed agenda operation; review before retry");
        if (message) { failedOperation = draft; error = message; return; }
        if (clearsFailedOperation(draft)) failedOperation = null;
        error = "";
        publishMutation(draft, data);
    }
    function activateUi(workspaceId): void { activateUiState(workspaceId); refresh(); }
    function deactivateUi(): void { closeModals(); readGeneration++; detailGeneration++; detailLoading = false; loading = false; debounce.stop(); deactivateUiState(); }
    onUiActiveChanged: {
        AgendaRepository.setActive(ownerId, uiActive);
        if (uiActive) refresh();
        else { closeModals(); readGeneration++; detailGeneration++; loading = false; detailLoading = false; debounce.stop(); }
    }
    onFilterTextChanged: { if (selection.queryText !== filterText) selection.queryText = filterText; refresh(); }
    onDayScopeChanged: { if (creationResult) detailsClosing(); creationResult = null; refresh(); }
    Component.onDestruction: AgendaRepository.setActive(ownerId, false)
    Component.onCompleted: { ownerId = AgendaRepository.ownerId(); AgendaRepository.setActive(ownerId, uiActive); if (uiActive) refresh(); }
    Timer { id: debounce; interval: 100; onTriggered: controller.readPage(false) }
    Core.SelectionModel {
        id: selection
        count: controller.items.length
        onQueryTextChanged: controller.filterText = queryText
        onSelectedIndexChanged: if (!controller.publishing) {
            controller.selectionSerial++;
            controller.retainedId = controller.items[selectedIndex]?.id || "";
            controller.creationResult = null;
        }
    }
    Core.KeyedListModel { id: rows }
    Connections {
        target: AgendaRepository
        function onResponse(owner: string, purpose: string, context: var, data: var, error: string): void {
            if (owner !== controller.ownerId) return;
            if (purpose === "list") controller.receiveList(context, data, error);
            else if (purpose === "mutation") controller.receiveMutation(context, data, error);
            else if (purpose === "receipt") controller.receiveReceipt(context, data, error);
            else if (purpose === "schedule") controller.receiveSchedule(context, data, error);
            else if (purpose === "get") controller.receiveItem(context, data, error);
        }
        function onInvalidated(): void { if (controller.uiActive) controller.refresh(); }
        function onDisconnected(): void { controller.readGeneration++; controller.detailGeneration++; controller.loading = false; controller.detailLoading = false; }
        function onAccepted(item: var): void {
            if (controller.creationResult?.id === item.id) controller.creationResult = item;
            if (controller.selectedSummary?.id === item.id) controller.detailItem = item;
            if (controller.items.some(old => old.id === item.id && old.revision < item.revision))
                controller.publish(controller.items.map(old => old.id === item.id ? AgendaRepository.summaryOf(item) : old));
        }
        function onRemoved(id: string): void {
            if (controller.creationResult?.id === id) { controller.detailsClosing(); controller.creationResult = null; }
            controller.publish(controller.items.filter(item => item.id !== id));
        }
    }
}
