import QtQuick
import QtTest
import "../../bar/BarProtocol.generated.js" as Bar
import "../../launcher/AppProtocol.generated.js" as App

TestCase {
    name: "GeneratedContracts"
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
}
