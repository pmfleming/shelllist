pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Ui as Ui

DaemonTestCase {
    id: tests
    name: "MaterialTheme"
    when: windowShown
    Component { id: factory; Io.MaterialTheme { active: true; publishTheme: true } }
    Component { id: paletteFactory; Ui.MaterialPalette {} }
    property int publication: 0
    function init() { calls = []; clientReady = true; publication = 0; }
    function published(roles) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/bar-reads.json"), false);
        request.send();
        const stamp = JSON.parse(request.responseText).changed["theme.changed"].data._publication;
        return Object.assign({}, roles, {_publication: Object.assign({}, stamp, {revision: ++publication})});
    }
    function requests(backend) { return calls.filter(call => call.route.consumerId === backend.sharedConsumerId); }
    function reply(call, roles) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id,
            {protocol: "bar-api", version: 2, ok: true, data: call.method === "theme.resolve" ? {theme: roles} : {theme: roles, snapshot: {theme: published(roles)}}}, "", call.route);
    }
    function push(call, roles) {
        const route = Object.assign({}, call.route, {kind: "base-subscription", localId: "session-subscribe"});
        emitBaseEvent("bar-daemon", route,
            {protocol: "bar-api", version: 2, stream: "theme.changed", event: "changed", data: published(roles)});
    }
    function test_startupRolesMatchNativeProducerFixtures() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/bar-controls.json"), false);
        request.send();
        const fixtures = JSON.parse(request.responseText);
        compare(Ui.ThemeDefaults.lightRoles, fixtures["theme.configure"].success.data.theme);
        compare(Ui.ThemeDefaults.darkRoles, fixtures["theme.resolve"].success.data.theme);
    }
    function test_rolesAreAtomicAndPreferencesAreReplayedAfterRestart() {
        const backend = createTemporaryObject(factory, tests);
        const palette = createTemporaryObject(paletteFactory, tests, {roles: Qt.binding(() => backend.roles || Ui.ThemeDefaults.lightRoles)});
        const first = requests(backend)[0];
        compare(first.method, "theme.configure");
        compare(first.params, {seed: "#6750a4", dark: false});
        reply(first, Ui.ThemeDefaults.lightRoles);
        compare(palette.primary, Ui.ThemeDefaults.lightRoles.primary);
        push(first, Ui.ThemeDefaults.darkRoles);
        compare(palette.primary, Ui.ThemeDefaults.darkRoles.primary);
        backend.accept({primary: "#000000"});
        compare(palette.primary, Ui.ThemeDefaults.darkRoles.primary, "partial state cannot replace a role map");
        backend.dark = true;
        tryVerify(() => requests(backend).length >= 2);
        const old = requests(backend).slice(-1)[0];
        const client = Io.DaemonSessions.sessions["bar-daemon"].client;
        clientReady = false;
        client.transportFailed("injected theme disconnect");
        clientReady = true;
        const current = requests(backend).slice(-1)[0];
        compare(current.params.dark, true);
        reply(current, Ui.ThemeDefaults.darkRoles);
        reply(old, Ui.ThemeDefaults.lightRoles);
        compare(palette.primary, Ui.ThemeDefaults.darkRoles.primary);
    }
    function test_previewIsReadOnlyAndStaleRepliesCannotReplaceNewerSeed() {
        const backend = createTemporaryObject(factory, tests, {publishTheme: false});
        const initial = requests(backend)[0];
        compare(initial.method, "theme.resolve");
        compare(backend.streams.length, 0);
        backend.seedColor = "#008577";
        tryVerify(() => requests(backend).length >= 2);
        const current = requests(backend).slice(-1)[0];
        compare(current.params.seed, "#008577");
        reply(current, Ui.ThemeDefaults.darkRoles);
        reply(initial, Ui.ThemeDefaults.lightRoles);
        compare(backend.roles, Ui.ThemeDefaults.darkRoles);
    }
}
