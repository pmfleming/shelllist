import QtQuick
import QtTest
import "../../qml/Shelllist/Io/JsonlRouting.js" as Routing

TestCase {
    name: "JsonlRouting"

    function test_classifiesAndNormalizesResponses() {
        verify(Routing.isFailureKind("transport-error"));
        verify(Routing.isFailureKind("protocol-error"));
        verify(!Routing.isFailureKind("event"));
        verify(Routing.shouldRecoverFailure("transport-error", false));
        verify(Routing.shouldRecoverFailure("protocol-error", true));
        verify(!Routing.shouldRecoverFailure("protocol-error", false));

        const outcome = Routing.responseOutcome({
            id: "request-1", ok: true,
            response: { protocol: "test-api", version: 1, ok: true, data: { value: 9 } }
        }, "test-daemon");
        compare(outcome.id, "request-1");
        compare(outcome.envelope.data.value, 9);
        compare(outcome.error, "");
        verify(!outcome.recover);
    }

}
