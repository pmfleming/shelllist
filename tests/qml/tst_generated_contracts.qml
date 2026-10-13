import QtQuick
import QtTest
import "../../launcher/AppProtocol.generated.js" as App
import "../../bar/BarProtocol.generated.js" as Bar

TestCase {
    name: "GeneratedContracts"
    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/" + name), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function test_productionAppRepliesMatchGeneratedRustSchemas() {
        const replies = fixture("app-replies.json");
        compare(Object.keys(App.contracts).length, 8);
        Object.keys(App.contracts).forEach(function(method) {
            compare(App.responseError(method, replies[method]), "", method);
            const moved = JSON.parse(JSON.stringify(replies[method]));
            const key = App.contracts[method].response_key;
            moved[key] = moved.data[key];
            delete moved.data[key];
            verify(App.responseError(method, moved).length > 0, "Moving a result out of data must fail: " + method);
        });
    }
    function test_audioFixturesMatchGeneratedRustSchemas() {
        const fixtures = fixture("bar-controls.json");
        compare(Object.keys(Bar.contracts).length, 3);
        Object.keys(Bar.contracts).forEach(function(method) {
            const values = fixtures[method];
            compare(Bar.requestError(method, values.params), "", method);
            verify(Bar.requestError(method, values.invalid_params).length > 0, method);
            for (const outcome of ["success", "limited"])
                compare(Bar.responseError(method, values[outcome]), "", method + ": " + outcome);
            const changed = JSON.parse(JSON.stringify(values.success));
            delete changed.data.audio.volume_percent;
            verify(Bar.responseError(method, changed).length > 0, "Rust reply fields cannot disappear silently");
        });
    }
    function test_nullabilityDefaultsUnknownFieldsAndExactIntegers() {
        compare(Bar.requestError("audio.setMuted", {}), "");
        compare(Bar.requestError("audio.setMuted", {muted:null}), "");
        verify(Bar.requestError("audio.setMuted", {muted:1}).length > 0);
        verify(Bar.requestError("audio.adjust", {delta_percent:40000}).length > 0);
        verify(App.requestError("applications.operation.status", {operation_id:"op", foreign:true}).length > 0);
        compare(App.requestError("applications.query", {}), "");
        verify(App.responseError("applications.revision", {ok:true, data:{revision:9007199254740992}}).length > 0);
    }
}
