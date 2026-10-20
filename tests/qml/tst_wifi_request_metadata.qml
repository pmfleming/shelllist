pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Wifi as Wifi

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
    function test_classificationIsCapturedFromMethodAndVariant_data() {
        return [
            {tag:"mutation-with-read-id", id:"networks", method:"wifi.profile.operation", params:{operation:"forget",path:"profile"}, exclusive:true, handler:"profile", execution:"effect"},
            {tag:"read-with-mutation-id", id:"disconnect", method:"wifi.profile.operation", params:{operation:"details",path:"profile"}, exclusive:false, handler:"advanced-load", execution:"read"},
            {tag:"unknown-with-portal-id", id:"portal-fake", method:"new.mutation", params:{}, exclusive:true, handler:"", execution:"effect"},
            {tag:"inherited-variant", id:"arbitrary", method:"wifi.profile.operation", params:{operation:"__proto__"}, exclusive:true, handler:"profile", execution:"effect"}
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
