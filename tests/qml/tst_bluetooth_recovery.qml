pragma ComponentBehavior: Bound
import QtQuick
import "../../bluetooth" as Bt

DaemonTestCase {
    id: testCase
    name: "BluetoothRecovery"
    when: windowShown
    visible: true
    width: 720
    height: 1000
    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias page: page
            Bt.BluetoothController {
                id: controller
            }
            Bt.BluetoothDevicePage {
                id: page
                anchors.fill: parent
                controller: panel.controller
            }
        }
    }
    function makePanel() {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.applySnapshot({
            radio: {
                available: true,
                operational: true,
                powered: true,
                adapter_count: 1
            },
            adapters: [
                {
                    key: "adapter",
                    alias: "Adapter",
                    powered: true
                }
            ],
            devices: [
                {
                    key: "buds",
                    name: "Buds",
                    paired: true,
                    connected: true,
                    adapter_key: "adapter",
                    battery: [],
                    services: [],
                    policy: {
                        reconnect_on_resume: true,
                        trust_after_pair: false,
                        power_on_connect: true,
                        wait_for_services: true,
                        audio_route_on_connect: "keep"
                    },
                    fast_pair: {
                        model_id: "aabbcc",
                        provisioning_available: true,
                        noise_control: {
                            available_modes: ["off", "transparent"],
                            settable_modes: ["off"],
                            active_mode: "transparent"
                        }
                    },
                    capabilities: {
                        can_set_noise_control: true,
                        can_provision_fast_pair: true,
                        can_rename: true
                    }
                }
            ]
        });
        wait(0); // complete queued startup reconciliation before testing an action
        const backend = findChild(panel.controller, "bluetoothBackend");
        verify(backend !== null);
        backend.pending = ({});
        panel.controller.applyAudioSnapshot([
            {
                device_key: "buds",
                sink: {
                    key: "output",
                    ready: true,
                    is_default: false
                },
                source: {
                    key: "input",
                    ready: true,
                    is_default: false
                },
                profiles: []
            }
        ]);
        calls = [];
        verify(panel.controller.hasSelection);
        return panel;
    }
    Component {
        id: adapterPageComponent
        Bt.BluetoothAdapterPage {}
    }
    function test_surfaceCloseClearsSecretsAndFencesLatePairingRecovery() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.uiActive = true;
        controller.handlePairingEvent({event: "requested", data: {
            request_id: "secret-a", device_key: "buds", kind: "pin-code", response_required: true
        }});
        controller.pairingInput = "123456";
        controller.handlePairingEvent({event: "requested", data: {
            request_id: "secret-b", device_key: "buds", kind: "passkey", response_required: true
        }});
        calls = [];
        controller.deactivateUi();
        compare(controller.pairingInput, "");
        compare(Object.keys(controller.pairingInputs).length, 0);
        compare(controller.pairingPrompts.length, 0);
        compare(calls.length, 2);
        for (const call of calls) {
            compare(call.method, "bluetooth.pairing.respond");
            compare(call.params.accept, false);
            verify(call.params.value === undefined, "cancellation must not send a credential");
        }
        const rejectedIds = calls.map(call => call.params.request_id);
        verify(rejectedIds.includes("secret-a") && rejectedIds.includes("secret-b"));
        controller.replacePairingPrompts([
            {request_id: "secret-a", response_required: true},
            {request_id: "secret-b", response_required: true}
        ]);
        verify(!controller.pairingPromptOpen, "late recovery cannot resurrect closed prompts");
        controller.handlePairingEvent({event: "requested", data: {
            request_id: "fresh", device_key: "buds", kind: "pin-code", response_required: true
        }});
        compare(controller.pairingPrompt.request_id, "fresh");
        compare(controller.pairingInput, "");
        controller.pairingInput = "2222";
        verify(controller.respondPairing(true));
        calls = [];
        controller.deactivateUi();
        compare(calls.length, 0, "an in-flight response must not be sent twice or contradicted");
        compare(controller.respondingPairingId, "fresh", "retain response ownership until completion");
        compare(controller.pairingInput, "");
        controller.finishPairingResponse(false);
        controller.replacePairingPrompts([{request_id: "fresh", response_required: true}]);
        verify(!controller.pairingPromptOpen, "a late failure cannot restore the closed credential prompt");
    }
    function test_pendingPairingReplyKeepsItsOriginalRequestIdentity() {
        const controller = makePanel().controller;
        controller.handlePairingEvent({
            event: "requested",
            data: {
                request_id: "a",
                device_key: "a",
                response_required: true
            }
        });
        controller.pairingInput = "123456";
        verify(controller.respondPairing(true));
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-response", {
            protocol: "bt-api", version: 2, ok: false,
            error: {code: "pairing-response-rejected", message: "Try again"}
        }, "");
        verify(!controller.pairingResponsePending);
        compare(controller.pairingPrompt.request_id, "a");
        compare(controller.pairingInput, "123456");
        verify(controller.respondPairing(true));
        controller.handlePairingEvent({
            event: "requested",
            data: {
                request_id: "b",
                device_key: "b",
                response_required: true
            }
        });
        controller.closePairingForDevice("a");
        controller.pairingInput = "654321";
        verify(!controller.respondPairing(true));
        compare(controller.respondingPairingId, "a");
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-response", {
            protocol: "bt-api",
            version: 2,
            ok: true,
            data: {}
        }, "");
        compare(controller.pairingPrompt.request_id, "b");
        compare(controller.pairingInput, "654321");
        verify(controller.respondPairing(true));
        compare(calls[calls.length - 1].params.request_id, "b");
    }
    function adapterCalls() {
        return calls.filter(call => call.method === "bluetooth.adapter.update");
    }
    function batchReply(key, changes, states) {
        return { protocol: "bt-api", version: 2, ok: true, data: { adapter_batch: {
            key: key, outcomes: Object.keys(changes).map(field => ({
                field: field, value: changes[field], state: (states || {})[field] || "applied",
                error: {message: "Acknowledgement lost"}
            }))
        } } };
    }
    function test_adapterPatchRejectsEntireInvalidDraft_data() {
        return [
            {tag: "blank-alias", fields: {alias: "  ", pairableTimeout: 0}},
            {tag: "invalid-timeout", fields: {alias: "Valid", discoverableTimeout: "not a number"}},
            {tag: "negative-timeout", fields: {alias: "Valid", pairableTimeout: -2}},
            {tag: "inherited-field", fields: {alias: "Valid", toString: 2}}
        ];
    }
    function test_adapterPatchRejectsEntireInvalidDraft(data) {
        const controller = makePanel().controller;
        const edits = controller.adapterEdits;
        edits.edit("adapter", "toString", 2);
        compare(Object.keys(edits.draft("adapter").fields).length, 0);
        edits.put("adapter", {fields: data.fields, error: "", pending: false});
        verify(!edits.saveBatch("adapter"));
        compare(adapterCalls().length, 0, "a valid sibling field cannot leak a partial patch");
        compare(edits.draft("adapter").fields, data.fields);
        verify(!edits.draft("adapter").pending);
        compare(edits.requestKey, "");
    }
    function test_adapterBatchPartialOutcomeAndExplicitRetry() {
        const panel = makePanel();
        const controller = panel.controller;
        const edits = controller.adapterEdits;
        const backend = findChild(controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "  My adapter  ");
        edits.edit("adapter", "discoverableTimeout", 120.4);
        edits.edit("adapter", "pairableTimeout", 0);
        verify(edits.saveBatch("adapter"));
        compare(adapterCalls().length, 1);
        const submitted = adapterCalls()[0].params;
        compare(submitted, {key: "adapter", changes: {alias: "My adapter", discoverable_timeout: 120, pairable_timeout: 0}});
        edits.edit("adapter", "alias", "Cannot retarget a submitted value");
        edits.discard("adapter");
        compare(edits.draft("adapter").fields.alias, "  My adapter  ");
        const partial = batchReply("adapter", submitted.changes,
            {discoverable_timeout: "unknown", pairable_timeout: "not-attempted"});
        partial.data.snapshot = {radio: controller.radio, devices: controller.allDevices,
            adapters: [{key: "adapter", alias: "My adapter", powered: true}]};
        backend.acceptSharedResponse("adapter-batch", partial, "");
        verify(controller.status.includes("not fully confirmed"), "snapshot status must not hide a partial outcome");
        compare(edits.draft("adapter").fields.alias, undefined);
        compare(edits.draft("adapter").fields.discoverableTimeout, 120.4);
        compare(edits.draft("adapter").fields.pairableTimeout, 0);
        verify(edits.draft("adapter").error.length > 0);
        // Saving another field must not silently retry the uncertain earlier write.
        edits.edit("adapter", "alias", "Another name");
        verify(!edits.saveBatch("adapter"));
        wait(750);
        compare(adapterCalls().length, 1);
        const page = createTemporaryObject(adapterPageComponent, panel, {
            controller: controller, width: 600, height: 900
        });
        wait(0);
        findChild(page, "retryAdapterSettings").clicked();
        compare(adapterCalls().length, 2);
        const retry = adapterCalls()[1].params.changes;
        compare(retry, {alias: "Another name", discoverable_timeout: 120, pairable_timeout: 0});
        page.destroy();
        wait(0);
        const response = batchReply("adapter", retry);
        response.data.adapter_batch.snapshot_error = {message: "Read unavailable"};
        backend.acceptSharedResponse("adapter-batch", response, "");
        compare(Object.keys(edits.draft("adapter").fields).length, 0);
        verify(controller.status.includes("snapshot unavailable"));
        wait(750);
        compare(adapterCalls().length, 2, "no frontend continuation, even after editor unload");
    }
}
