pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Wifi as Wifi

DaemonTestCase {
    id: tests
    name: "WifiStatusRecovery"
    when: windowShown
    Component { id: factory; Wifi.WifiController { uiActive: true; prompt: Wifi.WifiPromptController {} } }
    Component { id: inactiveFactory; Wifi.WifiController { prompt: Wifi.WifiPromptController {} } }
    property var loaded: null
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("../../contracts/nm-api-ui-contract.fixture.json"), false);
            request.send();
            loaded = JSON.parse(request.responseText).data.fixture.status_stream;
        }
        return JSON.parse(JSON.stringify(loaded));
    }
    function setup() {
        const c = createTemporaryObject(factory, tests);
        verify(c !== null);
        const session = Io.DaemonSessions.sessions["nm-daemon"];
        tryVerify(() => calls.some(r => r.route.consumerId === c.backend.sharedConsumerId && r.method === "wifi.status"));
        const read = calls.find(r => r.route.consumerId === c.backend.sharedConsumerId && r.method === "wifi.status");
        verify(read !== undefined, "ready establishes a read-only status baseline, including bar-only consumers");
        const data = fixture();
        for (const event of Object.values(data))
            event.data.status._publication.epoch += ":" + c.backend.sharedConsumerId;
        const consumer = session.consumers[c.backend.sharedConsumerId];
        const subscription = session.client.subscriptions.find(r => r.id === consumer.baseSubscriptionRequestId);
        verify(subscription !== undefined);
        return {c: c, session: session, read: read, eventRoute: subscription.route, data: data};
    }
    function reply(f, value, read) {
        const request = read || f.read;
        f.session.client.response(request.id, {protocol: "nm-api", version: 2, ok: true, data: {status: value}}, "", request.route);
    }
    function send(f, event) {
        emitBaseEvent("nm-daemon", f.eventRoute, event);
    }
    function status(f, name) { return f.data[name].data.status; }
    function test_deferredReadyReadUsesCurrentMonitorIntentWithoutBindingReentrancy() {
        failOnWarning(/Binding loop/);
        calls = [];
        const c = createTemporaryObject(inactiveFactory, tests);
        verify(c !== null);
        c.statusMonitorActive = true;
        c.statusMonitorActive = false;
        wait(0);
        compare(calls.length, 0, "retired monitor intent and secret-only consumers do not initiate reads");
        c.statusMonitorActive = true;
        tryVerify(() => calls.some(call => call.method === "wifi.status"));
        compare(calls.filter(call => call.method === "wifi.status").length, 1);
    }
    function test_initialAndLiveEventsFenceLateReadsDuplicatesAndRetiredEpochs() {
        const f = setup();
        send(f, f.data.lost);
        verify(f.c.activeStatus.active);
        reply(f, status(f, "initial"));
        send(f, f.data.initial);
        compare(f.c.backend.statusCursor.revision, 2);
        verify(f.c.activeStatus.active);
        const retired = fixture().restored;
        retired.data.status._publication.epoch = "retired";
        send(f, retired);
        verify(f.c.activeStatus.active);
        send(f, f.data.unavailable);
        compare(f.c.activeStatus, null);
        verify(!f.c.powered, "unavailable/loading is not inferred powered/ready");
        send(f, f.data.lost);
        compare(f.c.activeStatus, null);
        send(f, f.data.restored);
        verify(!f.c.activeStatus.active);
        compare(f.c.backend.statusCursor.revision, 4);
    }
    function test_malformedAndOldProducerDoNotConsumeRecoverableRevision() {
        const f = setup();
        const old = status(f, "initial");
        delete old._publication;
        reply(f, old);
        compare(f.c.activeStatus, null);
        compare(f.c.backend.statusCursor.revision, 0);
        const bad = fixture().lost;
        bad.data.status._publication = status(f, "lost")._publication;
        bad.data.status.radios.wireless_enabled = "yes";
        send(f, bad);
        compare(f.c.backend.statusCursor.revision, 0);
        send(f, f.data.lost);
        verify(f.c.activeStatus.active);
        compare(f.c.backend.statusCursor.revision, 2);
    }
    function test_malformedClock_data() {
        return [
            {tag: "zero", revision: 0, epoch: "current"},
            {tag: "string", revision: "2", epoch: "current"},
            {tag: "unsafe", revision: 9007199254740992, epoch: "current"},
            {tag: "empty-epoch", revision: 2, epoch: ""},
            {tag: "bad-lineage", revision: 2, epoch: "current", previous: true}
        ];
    }
    function test_malformedClock(data) {
        const f = setup();
        reply(f, status(f, "initial"));
        const bad = fixture().lost;
        bad.data.status._publication = {
            epoch: data.epoch === "current" ? status(f, "lost")._publication.epoch : data.epoch,
            revision: data.revision
        };
        if (data.previous)
            bad.data.status._publication.previous_epoch = bad.data.status._publication.epoch;
        send(f, bad);
        compare(f.c.backend.statusCursor.revision, 1);
        verify(!f.c.activeStatus.active);
        send(f, f.data.lost);
        verify(f.c.activeStatus.active);
        compare(f.c.backend.statusCursor.revision, 2, "malformed record cannot consume a recoverable revision");
    }
    function test_quietFinalLossRefreshIsReadOnlyAndPreservesPromptWorkAndPeers() {
        const f = setup();
        reply(f, status(f, "initial"));
        const peer = setup();
        reply(peer, status(peer, "initial"));
        f.c.connection.requestId = "accepted-connect";
        f.c.prompt.openPrompt("daemon-secret", "Credentials", "", true, null);
        f.c.prompt.secretRequestId = "captured-secret";
        f.c.prompt.text = "private unsaved fixture draft";
        const subscriptions = f.session.client.subscriptions.length;
        const cancellations = f.session.client.cancellations.length;
        calls = [];
        // The final changed event is deliberately not delivered. A later
        // explicit status check repairs it, without renewing secret observers.
        verify(f.c.backend.recoverStatus());
        verify(!f.c.backend.recoverStatus(), "only one read may be outstanding");
        compare(calls.length, 1);
        compare(calls[0].method, "wifi.status");
        reply(f, status(f, "lost"), calls[0]);
        verify(f.c.activeStatus.active);
        compare(f.c.connection.requestId, "accepted-connect");
        compare(f.c.prompt.secretRequestId, "captured-secret");
        compare(f.c.prompt.text, "private unsaved fixture draft");
        compare(f.session.client.subscriptions.length, subscriptions);
        compare(f.session.client.cancellations.length, cancellations);
        verify(!peer.c.activeStatus.active);
        verify(peer.c.backend.ready);
        compare(calls.length, 1, "no connect, scan, credential or settings replay");
    }
    function test_unavailableDoesNotCancelAcceptedScanOrCloseDraftsAndRestorationDoesNotScan() {
        const f = setup();
        reply(f, status(f, "initial"));
        f.c.scan.requestId = "accepted-scan";
        f.c.detailsOpen = true;
        f.c.prompt.openPrompt("daemon-secret", "Credentials", "", true, null);
        f.c.prompt.secretRequestId = "captured-secret";
        f.c.prompt.text = "unsaved fixture draft";
        calls = [];
        const cancellations = f.session.client.cancellations.length;
        send(f, f.data.unavailable);
        compare(f.c.scan.requestId, "accepted-scan");
        verify(f.c.detailsOpen);
        compare(f.c.prompt.text, "unsaved fixture draft");
        compare(f.session.client.cancellations.length, cancellations);
        send(f, f.data.restored);
        wait(0);
        compare(f.c.scan.requestId, "accepted-scan");
        compare(calls.length, 0, "status restoration is not scan authority");
    }
    function test_knownPowerOffAfterUnavailableRetainsTheExistingCleanupGuard() {
        const f = setup();
        reply(f, status(f, "initial"));
        f.c.scan.requestId = "accepted-scan";
        f.c.detailsOpen = true;
        send(f, f.data.unavailable);
        compare(f.c.scan.requestId, "accepted-scan");
        const cancellations = f.session.client.cancellations.length;
        send(f, f.data.off);
        compare(f.c.scan.requestId, "");
        verify(!f.c.detailsOpen);
        compare(f.session.client.cancellations.slice(cancellations), ["accepted-scan"]);
        compare(f.c.status, "Wi-Fi is off");
    }
    function test_statusReadSuccessOrFailureCannotResumeAnEarlierScanIntent() {
        const f = setup();
        reply(f, status(f, "initial"));
        f.c.scan.pendingRefresh = true;
        calls = [];
        verify(f.c.backend.recoverStatus());
        reply(f, status(f, "lost"), calls[0]);
        wait(0);
        compare(calls.length, 1);
        verify(f.c.scan.pendingRefresh, "status reads do not consume an earlier UI scan intention");
        verify(f.c.backend.recoverStatus());
        const read = calls[1];
        f.session.client.response(read.id, null, "synthetic read failure", read.route);
        wait(0);
        compare(calls.length, 2);
        verify(calls.every(call => call.method === "wifi.status"));
    }
    function test_reentrantPublicationCannotRollBackCursor() {
        const f = setup();
        let delivered = false;
        f.c.activeStatusChanged.connect(function () {
            if (!delivered && f.c.activeStatus && f.c.activeStatus.active) {
                delivered = true;
                send(f, f.data.unavailable);
            }
        });
        send(f, f.data.lost);
        verify(delivered);
        compare(f.c.activeStatus, null);
        compare(f.c.backend.statusCursor.revision, 3);
        reply(f, status(f, "initial"));
        compare(f.c.activeStatus, null);
        compare(f.c.backend.statusCursor.revision, 3);
    }
    function test_powerReceiptCannotOverwriteObservationAndUnavailableCannotGuessToggle() {
        const f = setup();
        reply(f, status(f, "lost"));
        calls = [];
        f.c.applyPowerResult({enabled: false, message: "Captured radio receipt"});
        verify(f.c.activeStatus.active);
        verify(f.c.powered);
        compare(f.c.backend.statusCursor.revision, 2);
        compare(calls.length, 1);
        compare(calls[0].method, "wifi.status");
        reply(f, status(f, "unavailable"), calls[0]);
        compare(f.c.activeStatus, null);
        compare(f.c.status, "Captured radio receipt");
        calls = [];
        f.c.setPower();
        compare(calls.length, 0, "unknown is not an inferred enable target");
    }
    function test_transportGenerationRetirementFencesOldResponsesAndEvents() {
        const f = setup();
        send(f, f.data.lost);
        const peer = setup();
        reply(peer, status(peer, "lost"));
        const oldSubscription = f.session.consumers[f.c.backend.sharedConsumerId].baseSubscriptionId;
        f.session.client.transportFailed("fixture owner retired");
        compare(f.c.activeStatus, null);
        compare(f.c.backend.statusCursor.revision, 0);
        compare(peer.c.activeStatus, null, "all consumers retire the lost transport authority");
        reply(f, status(f, "lost"));
        f.session.client.eventReceived(Object.assign({}, f.data.restored, {subscription_id: oldSubscription}), f.eventRoute);
        compare(f.c.activeStatus, null, "retired route traffic cannot establish a new baseline");
        compare(f.c.backend.statusCursor.revision, 0);
    }
}
