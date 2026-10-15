pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Bar as Bar

DaemonTestCase {
    id: tests
    name: "BarSessionControlContract"
    when: windowShown
    property var loaded: null
    Component { id: factory; Bar.BarController { surfaceRegistry: null } }
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-session-controls.json"), false);
            request.send(); loaded = JSON.parse(request.responseText);
        }
        return loaded;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() { calls = []; clientReady = true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function requests(c) { return calls.filter(call => call.route.consumerId === c.backend.sharedConsumerId); }
    function effects(c) { return requests(c).filter(call => call.method !== "bar.snapshot"); }
    function lastCall(c, method) {
        const found = requests(c).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(envelope), error || "", call.route);
    }
    function make() {
        const c = createTemporaryObject(factory, tests); verify(c !== null);
        reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        compare(c.activePlayerId, fixture().snapshot.data.snapshot.media.active_player);
        return c;
    }
    function start(c, key) {
        const example = fixture().cases[key];
        const params = example.params;
        let sent = false;
        if (key === "workspace") sent = c.focusWorkspace(params.workspace_id);
        else if (key === "updates") sent = c.backend.callSequenced("updates-refresh", example.method, clone(params));
        else if (["cycle", "automatic", "select", "set-mode"].includes(key))
            sent = c.backend.mediaPreference(key, params.player_id || "", params.mode || "");
        else if (key === "seek") sent = c.seekMedia(params.offset_seconds);
        else sent = c.mediaOperation(key);
        verify(sent, key);
        const call = lastCall(c, example.method);
        compare(call.params, params);
        verify(c.backend.isPending(call.route.localId));
        return call;
    }
    function test_noReplay_data() {
        return [["seek", true]]
            .map(([key, disconnect]) => ({tag: key + (disconnect ? "/disconnect" : "/timeout"), key: key, disconnect: disconnect}));
    }
    function test_noReplay(data) {
        const c = make(); const call = start(c, data.key);
        if (data.disconnect) {
            clientReady = false;
            Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Command outcome unknown");
            clientReady = true;
            reply(lastCall(c, "bar.snapshot"), fixture().snapshot);
        } else {
            reply(call, null, "Command outcome unknown");
            verify(c.backend.ready);
            compare(c.backend.operationError, "Command outcome unknown");
        }
        verify(!c.backend.isPending(call.route.localId));
        wait(0);
        compare(effects(c).length, 1, "Never replay playback, seek, focus or preference changes after uncertainty");
    }
}
