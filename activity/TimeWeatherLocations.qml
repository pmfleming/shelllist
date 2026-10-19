import QtQuick
import Shelllist.Io as Io
import "ActivityApi.js" as Api

Io.DaemonBackend {
    id: owner
    required property TimeWeatherController controller
    daemonName: "bar-daemon"
    expectedProtocol: Api.protocol
    expectedVersion: Api.version
    active: controller.uiActive || mutationId.length > 0

    property string error: ""
    property string pickerMode: ""
    property var removal: null
    readonly property bool modalOpen: pickerMode.length > 0 || removal !== null
    property int modalGeneration: 0
    property string query: ""
    property var candidates: []
    property string choice: ""
    property string searchId: ""
    property string statusId: ""
    property string mutationId: ""
    property string mutationKind: ""
    property int submittedGeneration: -1
    property string submittedFilter: ""
    property double capturedRevision: -1
    property var controlState: ({})
    property string operationKey: ""
    readonly property bool busy: mutationId.length > 0
    readonly property var catalog: controller.activity.location_catalog || ({})
    readonly property bool canAdd: !!catalog.writable && !busy
    readonly property bool canControl: controlState.available === true && !controlState.paused && !controlState.uncertain && !busy
    readonly property bool canAutomatic: canControl && controlState.manual === true
    readonly property bool canRemove: canAdd && controller.selectedCity.removable === true && !controller.selectedCity.home && !controller.selectedCity.current
    readonly property var selectedPlace: choice.length ? candidates[Number(choice)] || null : null
    readonly property var choiceOptions: candidates.map(function(place, index) {
        return {value: String(index), label: [place.name, place.region, place.country, place.timezone].filter(Boolean).join(" · ")};
    })
    readonly property var observedControl: controller.timezone.location_control || null
    onObservedControlChanged: if (observedControl) acceptControl(observedControl)

    function acceptControl(value: var): bool {
        if (!value || value.available !== true || typeof value.revision !== "number" || !Number.isFinite(value.revision)
                || typeof value.manual !== "boolean" || typeof value.paused !== "boolean" || typeof value.uncertain !== "boolean")
            return false;
        if (typeof controlState.revision === "number" && value.revision < controlState.revision)
            return false;
        controlState = value;
        return true;
    }
    function readStatus(): void {
        if (statusId || !controller.uiActive) return;
        statusId = nextRequestId("location-status");
        call(statusId, Api.methods.locationStatus, {});
    }
    function validPlace(place: var): bool {
        return !!place && typeof place.name === "string" && typeof place.timezone === "string"
            && place.name.length > 0 && place.timezone.length > 0
            && typeof place.latitude === "number" && Number.isFinite(place.latitude) && Math.abs(place.latitude) <= 90
            && typeof place.longitude === "number" && Number.isFinite(place.longitude) && Math.abs(place.longitude) <= 180;
    }
    function openPicker(mode: string): void {
        if (modalOpen || (mode === "add" ? !canAdd : !canControl)) return;
        error = "";
        modalGeneration++;
        capturedRevision = mode === "add" ? catalog.revision : controlState.revision;
        query = "";
        candidates = controller.cities.map(city => city.place).filter(place => validPlace(place));
        const place = controller.selectedCity.place;
        const index = mode === "manual" && place ? candidates.findIndex(p => p.name === place.name && p.latitude === place.latitude && p.longitude === place.longitude) : -1;
        choice = index >= 0 ? String(index) : "";
        pickerMode = mode;
    }
    function closeModal(): void {
        debounce.stop();
        searchId = "";
        pickerMode = "";
        removal = null;
        candidates = [];
        query = "";
        choice = "";
        modalGeneration++;
    }
    function editQuery(text: string): void {
        query = text;
        choice = "";
        candidates = [];
        searchId = "";
        error = "";
        debounce.restart();
    }
    function search(): void {
        if (!pickerMode || query.trim().length < 2) return;
        searchId = nextRequestId("location-search");
        call(searchId, Api.methods.locationsSearch, {query: query.trim()});
    }
    function selectChoice(value: string): void {
        if (Number.isInteger(Number(value)) && validPlace(candidates[Number(value)])) choice = value;
    }
    function submitPicker(): void {
        if (busy || !pickerMode || !validPlace(selectedPlace)) return;
        const revision = pickerMode === "add" ? catalog.revision : controlState.revision;
        if (capturedRevision !== revision) { error = qsTr("Location state changed. Cancel and choose again."); return; }
        if (pickerMode === "add" ? !canAdd : !canControl) return;
        submit(pickerMode, {place: selectedPlace, revision: capturedRevision});
    }
    function askRemove(): void {
        if (!canRemove || modalOpen) return;
        error = "";
        modalGeneration++;
        removal = {id: controller.selectedCity.id, label: controller.selectedCity.label, revision: catalog.revision};
    }
    function confirmRemove(): void {
        if (busy || !removal) return;
        const city = controller.cities.find(value => value.id === removal.id);
        if (!catalog.writable || catalog.revision !== removal.revision || !city || !city.removable || city.home || city.current) {
            error = qsTr("City list changed. Cancel and choose again."); return;
        }
        submit("remove", {id: removal.id, revision: removal.revision});
    }
    function returnAutomatic(): void {
        if (!canAutomatic || modalOpen) return;
        submit("automatic", {place: null, revision: controlState.revision});
    }
    function submit(kind: string, params: var): void {
        mutationKind = kind;
        mutationId = nextRequestId("location-mutation");
        submittedGeneration = modalGeneration;
        submittedFilter = controller.filterText;
        error = "";
        const methods = {add: Api.methods.locationsAdd, remove: Api.methods.locationsRemove, manual: Api.methods.locationSetManual, automatic: Api.methods.locationAutomatic};
        if (kind === "manual" || kind === "automatic") {
            operationKey = String(Date.now()) + "-" + Math.random().toString(36).slice(2) + "-" + mutationId;
            params = Object.assign({}, params, {request_id: operationKey});
        }
        call(mutationId, methods[kind], params);
    }
    function finish(id: string, envelope: var, transportError: string): void {
        if (id !== searchId && id !== statusId && id !== mutationId) return;
        const failure = responseError(envelope, transportError, qsTr("Location operation failed"));
        const data = envelope && envelope.data || ({});
        if (id === searchId) {
            searchId = "";
            if (!pickerMode) return;
            if (failure) {error = failure; return;}
            if (!Array.isArray(data.places) || data.places.length > 12 || data.places.some(place => !validPlace(place))) {
                error = qsTr("Invalid city search response"); return;
            }
            candidates = data.places;
            choice = "";
            if (!candidates.length) error = qsTr("No matching cities");
        } else if (id === statusId) {
            statusId = "";
            if (failure) { controlState = ({}); return; }
            acceptControl(data.location_control);
        } else {
            const kind = mutationKind;
            mutationId = "";
            mutationKind = "";
            if (failure) {
                error = failure;
                readStatus();
                controller.backend.snapshot();
                return;
            }
            if (kind === "manual" || kind === "automatic") {
                if (!data.location_control || data.location_control.operation_id !== operationKey
                        || data.location_control.operation_status !== "applied" || !acceptControl(data.location_control)) {
                    error = qsTr("Location outcome unconfirmed. Refresh before trying again.");
                    readStatus(); return;
                }
            } else {
                if (!data.activity || !data.activity.location_catalog || typeof data.id !== "string") {
                    error = qsTr("City save outcome unconfirmed. Refresh before trying again.");
                    controller.backend.snapshot(); return;
                }
                if (data.activity.location_catalog.revision >= Number(catalog.revision || 0)) controller.activity = data.activity;
            }
            const ownView = controller.uiActive && submittedGeneration === modalGeneration;
            if (ownView) closeModal();
            if (kind === "add" && ownView && controller.filterText === submittedFilter) {
                controller.filterText = "";
                controller.rebuildCityModel();
                const index = controller.filteredCities.findIndex(city => city.id === data.id);
                if (index >= 0) controller.selectionModel.selectedIndex = index;
            }
            controller.backend.snapshot();
        }
    }
    onResponseReceived: function(id, envelope, transportError) { finish(id, envelope, transportError); }
    onSendFailed: function(id, message) { finish(id, null, message); }
    onTransportFailed: function(message) {
        searchId = "";
        statusId = "";
        if (mutationId) error = qsTr("Location outcome unknown. Refresh before trying again.");
        else error = message;
        mutationId = "";
        controlState = ({});
    }
    onTransportReady: readStatus()
    Timer { id: debounce; interval: 600; onTriggered: owner.search() }
}
