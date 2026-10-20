import QtQuick
import QtTest
import "../../bar/BarProtocol.generated.js" as Bar
import "../../launcher/AppProtocol.generated.js" as App

TestCase {
    name: "GeneratedContracts"
    function fixture(name) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/" + name), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function test_sharedRuntimeKeepsClientSchemasIsolated() {
        verify(App.requestError("applications.execute", {}).length > 0);
        compare(Bar.requestError("applications.execute", {}), "");
        verify(Bar.requestError("audio.adjust", {}).length > 0);
        compare(App.requestError("audio.adjust", {}), "");
        const schema = {$defs: {value: {type: "integer", minimum: 1}}, $ref: "#/$defs/value"};
        compare(App.schemaError(schema, 2), "");
        compare(Bar.schemaError(schema, 2), "");
        verify(App.schemaError(schema, 0).length > 0);
        compare(Bar.schemaError(schema, 0), App.schemaError(schema, 0));
    }
    function test_controlFixturesMatchGeneratedRustSchemas() {
        const fixtures = fixture("bar-controls.json");
        Object.keys(Bar.contracts).forEach(function(method) {
            const values = fixtures[method];
            compare(Bar.requestError(method, values.params), "", method);
            if (values.invalid_params !== null)
                verify(Bar.requestError(method, values.invalid_params).length > 0, method);
            for (const outcome of ["success", "limited"])
                compare(Bar.responseError(method, values[outcome]), "", method + ": " + outcome);
            const changed = JSON.parse(JSON.stringify(values.success));
            const contract = Bar.contracts[method];
            delete changed.data[contract.response_key][contract.result_schema.required[0]];
            verify(Bar.responseError(method, changed).length > 0, "Rust reply fields cannot disappear silently");
        });
    }
}
