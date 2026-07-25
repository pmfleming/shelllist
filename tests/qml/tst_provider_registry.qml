import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    id: testCase
    name: "ProviderRegistry"

    property var dispatchedRequest: null

    function result(enabled) {
        return Core.Model.result({
            providerId: "test", id: "result", title: "Result",
            primaryActionId: "open",
            actions: [{ id: "open", label: "Open", role: "default", enabled: enabled }],
            payload: { key: "payload" }
        });
    }

    function init() {
        dispatchedRequest = null;
        rejectedSpy.clear();
        dispatchedSpy.clear();
    }

    function test_dispatchesDefaultAction() {
        verify(registry.execute(result(true), "", { workspaceId: "4" }));
        compare(dispatchedSpy.count, 1);
        verify(dispatchedRequest !== null);
        compare(dispatchedRequest.actionId, "open");
        compare(dispatchedRequest.context.workspaceId, "4");
    }

    function test_rejectsMissingResult() {
        verify(!registry.execute(null, "", {}));
        compare(rejectedSpy.count, 1);
    }

    function test_rejectsDisabledAction() {
        verify(!registry.execute(result(false), "open", {}));
        compare(rejectedSpy.count, 1);
        compare(rejectedSpy.signalArguments[0][0].code, "action-disabled");
    }

    Core.ProviderRegistry {
        id: registry

        Core.Provider {
            providerId: "test"
            displayName: "Test"
            function execute(request) {
                testCase.dispatchedRequest = request;
                return true;
            }
        }
    }

    SignalSpy { id: rejectedSpy; target: registry; signalName: "actionRejected" }
    SignalSpy { id: dispatchedSpy; target: registry; signalName: "actionDispatched" }
}
