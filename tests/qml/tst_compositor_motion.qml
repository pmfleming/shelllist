pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io

DaemonTestCase {
    id: testCase
    name: "NativeCompositorMotion"
    Component {
        id: motionFactory
        Io.CompositorMotion { active: true }
    }
    function backend(client) { return findChild(client, "compositorMotionBackend"); }
    function update(client, value) {
        backend(client).acceptSharedEvent({protocol: "bar-api", version: 1,
            stream: "compositor.changed", event: "changed", data: Object.assign({revision: client.revision + 1}, value)});
    }
    function test_nativeSnapshotEventsRecoveryAndNoFrontendPolling() {
        const client = createTemporaryObject(motionFactory, testCase);
        verify(client !== null);
        wait(0);
        const transport = backend(client);
        compare(Array.from(transport.streams), ["compositor.changed"]);
        transport.acceptSharedResponse("compositor-snapshot", {
            protocol: "bar-api", version: 1, ok: true,
            data: {snapshot: {compositor: {available: true, revision: 1, animations_enabled: false, error: null}}}
        }, "");
        verify(client.reduced && client.available);
        transport.acceptSharedEvent({protocol: "bar-api", version: 1,
            stream: "workarea.changed", event: "changed", data: {revision: 99, animations_enabled: true}});
        compare(client.revision, 1, "a different projection cannot alter motion");
        transport.acceptSharedResponse("compositor-snapshot", null, "read failed");
        verify(client.reduced && !client.available);
        compare(client.revision, 1, "a failed read is not a new daemon lifetime");
        update(client, {available: true, revision: 0, animations_enabled: true});
        verify(client.reduced, "an old snapshot cannot overwrite a newer stream event");
        const requests = calls.length;
        wait(1100);
        compare(calls.length, requests, "no frontend option polling");
        update(client, {available: false, animations_enabled: false, error: "offline"});
        verify(client.reduced && !client.available);
        transport.failSharedTransport("disconnected");
        verify(client.reduced && !client.available, "disconnect cannot re-enable motion");
        compare(client.revision, -1, "a restarted daemon may begin a new revision sequence");
        update(client, {available: false, animations_enabled: null, error: "restarting"});
        verify(client.reduced, "unknown observations retain the local last-known value");
        update(client, {available: true, animations_enabled: "false"});
        verify(client.reduced, "malformed booleans are not coerced");
        transport.acceptSharedEvent({protocol: "bar-api", version: 1,
            stream: "compositor.changed", event: "lagged"});
        compare(calls[calls.length - 1].method, "bar.snapshot");
        update(client, {available: true, animations_enabled: true, error: null});
        verify(!client.reduced && client.available, "new authoritative preference applies");
        client.active = false;
        update(client, {available: true, animations_enabled: false, error: null});
        verify(!client.reduced && !client.available, "inactive/overridden readers ignore late events");
    }
}
