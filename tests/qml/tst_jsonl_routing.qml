import QtQuick
import QtTest
import "../../qml/Shelllist/Io/JsonlRouting.js" as Routing

TestCase {
    name: "JsonlRouting"

    function test_classifiesFailures() {
        verify(Routing.isFailureKind("transport-error"));
        verify(Routing.isFailureKind("protocol-error"));
        verify(!Routing.isFailureKind("event"));
        verify(Routing.shouldRecoverFailure("transport-error", false));
        verify(Routing.shouldRecoverFailure("transport-error", true));
        verify(!Routing.shouldRecoverFailure("protocol-error", false));
        verify(Routing.shouldRecoverFailure("protocol-error", true));
    }

    function test_normalizesSuccessfulResponse() {
        const envelope = { protocol: "test-api", version: 1, ok: true, data: { value: 9 } };
        const outcome = Routing.responseOutcome({
            id: "request-1", ok: true, response: envelope
        }, "test-daemon");
        compare(outcome.id, "request-1");
        compare(outcome.envelope.data.value, 9);
        compare(outcome.error, "");
        verify(!outcome.recover);
    }

    function test_subscriptionFailureRequestsRecovery() {
        const outcome = Routing.responseOutcome({
            id: "session-subscribe", ok: false, error: "subscription refused"
        }, "test-daemon");
        compare(outcome.error, "subscription refused");
        verify(outcome.recover);
    }

    function test_extractsSubscriptionId() {
        compare(Routing.subscriptionId({
            id: "session-subscribe", ok: true,
            response: { data: { subscription: { id: "subscription-1" } } }
        }), "subscription-1");
        compare(Routing.subscriptionId({ id: "other", ok: true }), "");
    }

    function test_extractsOnDemandSubscriptionId() {
        verify(Routing.isExtraSubscribe("subscribe-3"));
        verify(!Routing.isExtraSubscribe("session-subscribe"));
        verify(!Routing.isExtraSubscribe("networks"));
        compare(Routing.subscriptionId({
            id: "subscribe-3", ok: true,
            response: { data: { subscription: { id: "subscription-9" } } }
        }), "subscription-9");
    }

    function test_onDemandSubscriptionFailureDoesNotTearDownTheSession() {
        const outcome = Routing.responseOutcome({
            id: "subscribe-3", ok: false, error: "subscription refused"
        }, "test-daemon");
        compare(outcome.error, "subscription refused");
        verify(!outcome.recover);
    }
}
