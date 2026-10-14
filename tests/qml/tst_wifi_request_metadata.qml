pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Wifi as Wifi
import "../../wifi/NmApi.js" as NmApi

DaemonTestCase {
    id: tests
    name: "WifiRequestMetadata"
    when: windowShown
    Component { id: factory; Wifi.WifiController { prompt: Wifi.WifiPromptController {} } }
    function make() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        controller.backend.pending = ({});
        controller.backend.requestMetadata = ({});
        calls = [];
        return controller;
    }
    function init() {
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function test_everyFrontendMethodHasAnExplicitResponseRoute() {
        const c = make();
        Object.keys(NmApi.methods).forEach(function(name) {
            const method = NmApi.methods[name];
            const info = c.backend.classifyRequest(method, {});
            verify(info.responseHandler.length > 0, method);
            verify(["portal", "connection-status"].includes(info.responseHandler) || !!c.backend.responseHandlers[info.responseHandler], method);
        });
    }
    function test_classificationIsCapturedFromMethodAndVariant_data() {
        return [
            {tag:"mutation-with-read-id", id:"networks", method:"wifi.profile.operation", params:{operation:"forget",path:"profile"}, exclusive:true, handler:"profile", execution:"effect"},
            {tag:"read-with-mutation-id", id:"disconnect", method:"wifi.profile.operation", params:{operation:"details",path:"profile"}, exclusive:false, handler:"advanced-load", execution:"read"},
            {tag:"unknown-with-portal-id", id:"portal-fake", method:"new.mutation", params:{}, exclusive:true, handler:"", execution:"effect"},
            {tag:"cache-refresh-is-not-a-read", id:"networks", method:"wifi.networks", params:{cached:true,refresh_cache:true}, exclusive:false, handler:"networks", execution:"operation"},
            {tag:"connect-is-not-a-read", id:"arbitrary", method:"wifi.connectTarget", params:{}, exclusive:false, handler:"connect-start", execution:"operation"},
            {tag:"portal-is-independent-effect", id:"arbitrary", method:"network.portalClaim", params:{}, exclusive:false, handler:"portal", execution:"effect"},
            {tag:"status-without-prefix", id:"arbitrary", method:"operation.status", params:{request_id:"op"}, exclusive:false, handler:"connection-status", execution:"read"}
        ];
    }
    function test_classificationIsCapturedFromMethodAndVariant(data) {
        const c = make();
        const params = Object.assign({password:"must-not-be-retained"}, data.params);
        verify(c.backend.call(data.id, data.method, params));
        const metadata = c.backend.requestMetadata[data.id];
        compare(metadata.method, data.method);
        compare(metadata.responseHandler, data.handler);
        compare(metadata.execution, data.execution);
        compare(c.backend.nonConnectRunning, data.exclusive);
        verify(!JSON.stringify(metadata).includes("must-not-be-retained"));
        params.operation = "details";
        compare(c.backend.requestMetadata[data.id].execution, data.execution, "later parameter mutation cannot reclassify sent work");
        verify(!c.backend.call(data.id, "wifi.status", {}));
        verify(c.backend.requestMetadata[data.id] === metadata, "duplicate IDs cannot replace pending classification");
        clientReady = false;
        c.backend.failSharedTransport("injected owner loss");
        compare(Object.keys(c.backend.requestMetadata).length, 0);
    }
    function test_controlLookingCallIdStillRoutesAsCallAndCleansUp() {
        const c = make();
        verify(c.backend.call("subscribe-not-a-control", "wifi.disconnect", {}));
        const call = calls[calls.length - 1];
        Io.DaemonSessions.sessions["nm-daemon"].client.response(call.id, null, "injected lost reply", call.route);
        verify(c.status.includes("injected lost reply"));
        compare(Object.keys(c.backend.requestMetadata).length, 0);
        compare(c.backend.nonConnectRunning, false);
    }
    function test_sendExceptionRetiresMetadata() {
        const c = make();
        const sessions = Io.DaemonSessions.sessions;
        try {
            Io.DaemonSessions.sessions = ({});
            verify(!c.backend.call("arbitrary", "wifi.profile.operation", {operation:"update"}));
            compare(Object.keys(c.backend.requestMetadata).length, 0);
            compare(Object.keys(c.backend.pending).length, 0);
            verify(c.status.includes("unavailable"));
        } finally {
            Io.DaemonSessions.sessions = sessions;
        }
    }
    function test_completionCannotDeleteMetadataForReusedId() {
        const c = make();
        let reentered = false;
        c.backend.responseReceived.connect(function(id) {
            if (id === "same" && !reentered) {
                reentered = true;
                verify(c.backend.call("same", "wifi.profile.operation", {operation:"forget"}));
            }
        });
        verify(c.backend.call("same", "wifi.status", {}));
        c.backend.acceptSharedResponse("same", null, "injected read failure");
        verify(reentered);
        verify(c.backend.isPending("same"));
        compare(c.backend.requestMetadata.same.responseHandler, "profile");
        compare(c.backend.nonConnectRunning, true);
    }
    function test_rejectionRetiresMetadataAndDoesNotDispatch() {
        const c = make();
        c.backend.validateRequest = function() { return "invalid"; };
        verify(!c.backend.call("anything", "wifi.profile.operation", {operation:"update"}));
        compare(calls.length, 0);
        compare(Object.keys(c.backend.requestMetadata).length, 0);
        verify(c.status.includes("invalid"));
    }
}
