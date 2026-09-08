#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const [apiPath, protocolPath, controllerPath, backendPath] = process.argv.slice(2);
if (!backendPath)
    throw new Error("usage: check-clipboard-actions.js <ClipApi.js> <ClipProtocol.generated.js> <ClipboardController.qml> <ClipboardBackend.qml>");
const apiSource = fs.readFileSync(apiPath, "utf8");
const Protocol = {};
vm.createContext(Protocol);
vm.runInContext(fs.readFileSync(protocolPath, "utf8").replace(/^\.pragma library\s*/, ""), Protocol);
const api = { Protocol };
vm.createContext(api);
vm.runInContext(apiSource.replace(/^\.(pragma|import).*$/gm, ""), api);

// Keep distinct action capabilities, not every text subtype or exact UI labels.
for (const [kind, action] of [["link", "open-url"], ["image", "annotate"],
    ["files", "reveal-file"], ["binary", "copy"]]) {
    const descriptors = api.actionDescriptorsForKind(kind);
    assert.ok(descriptors.some(item => item.id === action), `${kind} offers ${action}`);
    assert.equal(descriptors.filter(item => item.role === "default").length, 1,
        `${kind} has one default action`);
}

const source = fs.readFileSync(controllerPath, "utf8");
const backendSource = fs.readFileSync(backendPath, "utf8");
function install(context, text, names) {
    vm.createContext(context);
    for (const name of names) {
        const match = text.match(new RegExp("    function " + name + "\\([^)]*\\)[^{]*\\{[\\s\\S]*?\\n    \\}"));
        vm.runInContext(match[0].replace(/:\s*(var|bool|int|string|void)\b/g, ""), context);
    }
}

// Execute the actual annotation lifecycle. Hiding the chooser must not cancel
// its background transport, and completion must restore the edited position.
{
    const controller = {
        uiActive: true, selectedIndex: 37, sessionId: "", activeAction: "",
        activeOperationId: "", actionInFlight: false,
        detailState: { clear() {} }, finishEditSession() {}, leaveMultiSelect() {},
        deactivateUiState() { controller.uiActive = false; },
        runAction(action) {
            controller.activeAction = action;
            controller.activeOperationId = "annotation-1";
            controller.actionInFlight = true;
            return true;
        },
        scheduleRefresh() {}
    };
    Object.defineProperty(controller, "backgroundOperationInFlight", { get: () =>
        vm.runInContext(source.match(/readonly property bool backgroundOperationInFlight: ([\s\S]*?)\n    signal/)[1], controller) });
    install(controller, source, ["annotateImage", "deactivateUi", "finishAnnotate"]);
    controller.annotateImage();
    controller.deactivateUi();
    assert.equal(controller.activeOperationId, "annotation-1", "hiding preserves the in-flight annotation");
    const transport = vm.createContext({ controller });
    assert.equal(vm.runInContext(backendSource.match(/^    active: (.*)$/m)[1], transport), true,
        "background annotation keeps the real backend active");
    controller.finishAnnotate();
    assert.equal(controller.selectionIndexAfterRefresh, 37, "annotation restores history position, not the old content ID");
}

// Bulk deletion crosses the backend boundary once, retaining every revision.
{
    const requests = [];
    const backend = { ClipApi: api, call: (...args) => { requests.push(args); return true; } };
    install(backend, backendSource, ["deleteEntries"]);
    const controller = { backend, multiSelectedCount: 2, actionInFlight: false,
        multiSelectedEntries: [{ id: "one", revision: 4 }, { id: "two", revision: 9 }] };
    install(controller, source, ["confirmBulkDelete"]);
    controller.confirmBulkDelete();
    controller.confirmBulkDelete();
    assert.equal(requests.length, 1, "an in-flight delete cannot be dispatched twice");
    assert.equal(requests[0][1], "clipboard.entries.delete");
    assert.deepEqual(JSON.parse(JSON.stringify(requests[0][2])), {
        entries: [{ entry_id: "one", revision: 4 }, { entry_id: "two", revision: 9 }]
    });
}
console.log("clipboard actions: capabilities, background annotation and revision-checked bulk deletion passed");
