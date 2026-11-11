pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io

DaemonTestCase {
    id: testCase
    name: "Storage"
    when: windowShown
    visible: true
    width: 900
    height: 700
    Component {
        id: factory
        Item {
            anchors.fill: parent
            property alias controller: controller
            property alias content: content
            Bar.StorageController { id: controller }
            Bar.StorageContent { id: content; anchors.fill: parent; controller: controller }
        }
    }
    function init(): void { calls = []; failOnWarning(/.*/); }
    function last(method: string): var { return calls.filter(c => c.method === method).slice(-1)[0]; }
    function answer(call: var, data: var): void {
        Io.DaemonSessions.sessions["storage-daemon"].client.response(call.id, {protocol: "storage-api", version: 1, ok: true, data: data}, "", call.route);
    }
    function fixture(): var {
        const root = createTemporaryObject(factory, testCase);
        verify(root !== null);
        root.controller.activateUi("");
        tryVerify(() => !!last("storage.getState"));
        answer(last("storage.getState"), {busy: "", error: "", history: [],
            policy: {shutdown_enabled: true, project_budget_gib: 64, shared_budget_gib: 8, warm_hours: 24, retention_days: 14, log_retention_days: 30, excluded_projects: []},
            snapshot: {revision: "reviewed-1", scanned_at: 1000, complete: true, errors: [], filesystem_available: 1000000000,
                usage: Array.from({length: 1000}, (_, i) => ({path: "/Projects/" + i, category: "projects", bytes: 123456})),
                candidates: [{path: "/Projects/p/target/debug", reason: "Retention expired", eligible: true, bytes: 123456}]}});
        tryVerify(() => root.controller.canAct);
        return root;
    }
    function test_explicit_cleanup_uses_preview_and_cancel_remains_available(): void {
        const root = fixture();
        const list = findChild(root, "storageList");
        tryCompare(list, "count", 1000);
        verify(list.contentItem.children.length < 50);
        verify(!last("storage.clean") && !last("storage.scan"));
        mouseClick(findChild(root, "storageClean"));
        compare(last("storage.clean").params.revision, "reviewed-1");
        answer(last("storage.clean"), {accepted: true});
        tryVerify(() => root.controller.backend.isPending("state"));
        answer(last("storage.getState"), Object.assign({}, root.controller.storageState, {busy: "cleanup"}));
        verify(!findChild(root, "storageClean").enabled);
        verify(findChild(root, "storageCancel").enabled);
        mouseClick(findChild(root, "storageCancel"));
        verify(!!last("storage.cancel"));
    }
    function test_policy_fields_stage_discard_commit_and_wait_for_ack(): void {
        const root = fixture();
        root.controller.viewTab = "policy";
        tryVerify(() => root.content.detailsNavigation.contentReady);
        const field = findChild(root, "storagePolicy:project_budget_gib");
        tryVerify(() => !root.content.detailsNavigation.pendingMemory);
        root.content.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Tab);
        tryCompare(root.content.detailsNavigation, "highlightedControl", field);
        keyClick(Qt.Key_Return);
        tryVerify(() => root.content.detailsNavigation.editing);
        keyClick(Qt.Key_Down);
        verify(!last("storage.setPolicy"));
        keyClick(Qt.Key_Escape);
        compare(root.controller.policy.project_budget_gib, 64);
        root.content.detailsNavigation.focusContent(true);
        keyClick(Qt.Key_Tab);
        tryCompare(root.content.detailsNavigation, "highlightedControl", field);
        keyClick(Qt.Key_Return);
        tryVerify(() => root.content.detailsNavigation.editing);
        wait(20);
        keyClick(Qt.Key_Down);
        wait(20);
        keyClick(Qt.Key_Return);
        tryVerify(() => !!last("storage.setPolicy"));
        compare(last("storage.setPolicy").params.project_budget_gib, 128);
        compare(root.controller.policy.project_budget_gib, 64);
        verify(!field.interactive);
    }
    function test_unchanged_pins_do_not_write_policy_on_focus_loss(): void {
        const root = fixture();
        root.controller.viewTab = "policy";
        const pins = findChild(root, "storagePins");
        tryVerify(() => pins.visible);
        pins.forceActiveFocus();
        findChild(root, "storagePolicy:project_budget_gib").forceActiveFocus();
        wait(20);
        verify(!last("storage.setPolicy"));
        pins.editingFinished();
        verify(!last("storage.setPolicy"));
        pins.text = "/Projects/keep";
        pins.editingFinished();
        compare(last("storage.setPolicy").params.excluded_projects[0], "/Projects/keep");
    }
}
