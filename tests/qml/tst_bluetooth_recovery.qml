pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
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
    function test_unavailableInvalidatesCapabilitiesAndSelection() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.handlePairingEvent({
            event: "requested",
            data: {
                request_id: "a",
                device_key: "buds",
                response_required: true
            }
        });
        const sink = controller.selectedSink;
        controller.applySnapshot({radio: controller.radio, adapters: controller.adapters,
            devices: [Object.assign({}, controller.selectedDevice, {connected: false})]});
        verify(!controller.setAudioDefault(sink), "cached audio endpoints cannot outlive connection capability");
        verify(!controller.setAudioProfile({key: "sbc"}));
        controller.invalidateBluetooth("BlueZ unavailable");
        verify(!controller.hasSelection);
        verify(controller.globalRequestInFlight);
        compare(controller.audioDevices.length, 0);
        compare(controller.adapters.length, 0);
        compare(controller.pairingPrompts.length, 0);
        verify(!controller.setAudioDefault({
            key: "stale",
            ready: true
        }));
        compare(calls.length, 0);
    }
    function test_pairingInputSurvivesUnrelatedOperationsAndQueueRecovery() {
        const controller = makePanel().controller;
        const first = {
            request_id: "pair-a",
            device_key: "a",
            kind: "passkey",
            response_required: true
        };
        const second = {
            request_id: "pair-b",
            device_key: "b",
            kind: "passkey",
            response_required: true
        };
        controller.handlePairingEvent({
            event: "requested",
            data: first
        });
        controller.pairingInput = "123456";
        controller.handleOperationEvent({
            request_id: "op-c",
            device_key: "c",
            operation: "connect",
            state: "completed"
        });
        compare(controller.pairingPrompt.request_id, "pair-a");
        compare(controller.pairingInput, "123456");
        controller.applyRequestSnapshot({
            pairing: {
                active: [first, second]
            }
        });
        compare(controller.pairingInput, "123456");
        controller.applyRequestSnapshot({
            pairing: {
                active: [second, first]
            }
        });
        compare(controller.pairingInput, "");
        controller.pairingInput = "654321";
        controller.applyRequestSnapshot({
            pairing: {
                active: [first, second]
            }
        });
        compare(controller.pairingInput, "123456");
        controller.closePairingForDevice("a");
        compare(controller.pairingInput, "654321");
        compare(controller.pairingInputs["pair-a"], undefined);
        controller.invalidateBluetooth("Disconnected");
        compare(controller.pairingInput, "");
        compare(Object.keys(controller.pairingInputs).length, 0);
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
            protocol: "bt-api", version: 1, ok: false,
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
            version: 1,
            ok: true,
            data: {}
        }, "");
        compare(controller.pairingPrompt.request_id, "b");
        compare(controller.pairingInput, "654321");
        verify(controller.respondPairing(true));
        compare(calls[calls.length - 1].params.request_id, "b");
    }
    function setupAudioProfile(panel) {
        panel.controller.applyAudioSnapshot([
            {
                device_key: "buds",
                active_profile_key: "sbc",
                profiles: [
                    {
                        key: "sbc",
                        label: "SBC"
                    },
                    {
                        key: "aac",
                        label: "AAC"
                    },
                    {
                        key: "unavailable",
                        label: "Unavailable",
                        available: false
                    }
                ]
            }
        ]);
        return findChild(panel.page, "currentAudioProfile");
    }
    function test_audioProfileSingleNativeOperationPreservesPartialSuccess() {
        const panel = makePanel();
        const profile = setupAudioProfile(panel);
        const backend = findChild(panel.controller, "bluetoothBackend");
        compare(findChild(panel.page, "audioProfileOnConnect"), null);
        compare(profile.value, "sbc");
        profile.activated(profile.optionIndex("unavailable"));
        compare(calls.length, 0);
        profile.selected("aac");
        backend.acceptSharedResponse("audio-set-profile", {
            protocol: "bt-api", version: 1, ok: false,
            error: {message: "Profile unavailable"}
        }, "");
        compare(calls.length, 1, "a rejected profile must not be remembered");
        compare(profile.value, "sbc");
        verify(profile.interactive);
        calls = [];
        profile.forceActiveFocus();
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        compare(calls.length, 0, "choice drafts must not write");
        keyClick(Qt.Key_Escape);
        compare(calls.length, 0, "discard must not write");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.audio.setProfile");
        compare(calls[0].params.device_key, "buds");
        compare(calls[0].params.profile_key, "aac");
        compare(calls[0].params.remember, true);
        verify(!profile.interactive);
        panel.controller.applySnapshot({
            radio: panel.controller.radio,
            adapters: panel.controller.adapters,
            devices: [
                {
                    key: "other",
                    name: "Other",
                    paired: true
                }
            ]
        });
        backend.acceptSharedResponse("audio-set-profile", {
            protocol: "bt-api",
            version: 1,
            ok: true,
            data: {
                audio_devices: [
                    {
                        device_key: "buds",
                        active_profile_key: "aac"
                    }
                ],
                profile_outcome: {applied: true, remembered: false, persistence_error: "Permission denied"}
            }
        }, "");
        compare(calls.length, 1, "selection changes and partial success must not trigger another write");
        verify(!backend.requestRunning);
        compare(panel.controller.status, "Audio profile applied, but could not remember it: Permission denied");
    }
    function findToggle(item, title) {
        if (item.title === title && item.checked !== undefined)
            return item;
        for (const child of item.children || []) {
            const match = findToggle(child, title);
            if (match)
                return match;
        }
        return null;
    }
    function test_renameDraftSurvivesFailureAndEditorRecreation() {
        const panel = makePanel();
        const controller = panel.controller;
        const backend = findChild(controller, "bluetoothBackend");
        verify(controller.renameSelected("My renamed buds"));
        verify(controller.nameEdits.draft("buds").dirty);
        verify(controller.nameEdits.draft("buds").pending);
        backend.acceptSharedResponse("device-set-alias", {
            protocol: "bt-api",
            version: 1,
            ok: true,
            data: {
                operation: {
                    request_id: "rename-1",
                    device_key: "buds",
                    operation: "set-alias",
                    state: "running"
                }
            }
        }, "");
        controller.handleOperationEvent({
            request_id: "rename-1",
            device_key: "buds",
            operation: "set-alias",
            state: "failed",
            error: {
                message: "Permission denied"
            }
        });
        wait(0);
        compare(findChild(panel.page, "deviceNameInput").text, "My renamed buds");
        const callCount = calls.length;
        wait(750);
        compare(calls.length, callCount); // Failed saves must not retry indefinitely.
        const newPage = createTemporaryObject(devicePageComponent, panel, {
            controller: controller,
            width: 600,
            height: 900
        });
        wait(0);
        compare(findChild(newPage, "deviceNameInput").text, "My renamed buds");
        findChild(newPage, "retryDeviceName").clicked();
        compare(calls[calls.length - 1].params.alias, "My renamed buds");
        backend.acceptSharedResponse("device-set-alias", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {
                message: "Adapter unavailable"
            }
        }, "");
        verify(controller.nameEdits.draft("buds").dirty);
        verify(!controller.nameEdits.draft("buds").pending);
        findChild(newPage, "discardDeviceName").clicked();
        compare(findChild(newPage, "deviceNameInput").text, "Buds");
        compare(controller.nameEdits.draft("buds"), null);
    }
    Component {
        id: devicePageComponent
        Bt.BluetoothDevicePage {}
    }
    function adapterCalls() {
        return calls.filter(call => call.method === "bluetooth.adapter.update");
    }
    function batchReply(key, changes, states) {
        return { protocol: "bt-api", version: 1, ok: true, data: { adapter_batch: {
            key: key, outcomes: Object.keys(changes).map(field => ({
                field: field, value: changes[field], state: (states || {})[field] || "applied",
                error: {message: "Acknowledgement lost"}
            }))
        } } };
    }
    function test_adapterBatchPartialOutcomeAndExplicitRetry() {
        const panel = makePanel();
        const controller = panel.controller;
        const edits = controller.adapterEdits;
        const backend = findChild(controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "My adapter");
        edits.edit("adapter", "discoverableTimeout", 120);
        edits.edit("adapter", "pairableTimeout", 0);
        verify(edits.saveBatch("adapter"));
        compare(adapterCalls().length, 1);
        const submitted = adapterCalls()[0].params;
        compare(submitted, {key: "adapter", changes: {alias: "My adapter", discoverable_timeout: 120, pairable_timeout: 0}});
        edits.edit("adapter", "alias", "Cannot retarget a submitted value");
        edits.discard("adapter");
        compare(edits.draft("adapter").fields.alias, "My adapter");
        const partial = batchReply("adapter", submitted.changes,
            {discoverable_timeout: "unknown", pairable_timeout: "not-attempted"});
        partial.data.snapshot = {radio: controller.radio, devices: controller.allDevices,
            adapters: [{key: "adapter", alias: "My adapter", powered: true}]};
        backend.acceptSharedResponse("adapter-batch", partial, "");
        verify(controller.status.includes("not fully confirmed"), "snapshot status must not hide a partial outcome");
        compare(edits.draft("adapter").fields.alias, undefined);
        compare(edits.draft("adapter").fields.discoverableTimeout, 120);
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
    function test_adapterBatchRejectsMalformedAndLostOutcomes_data() {
        return [ {tag: "missing"}, {tag: "wrong-key"}, {tag: "wrong-value"},
            {tag: "duplicate"}, {tag: "unknown-state"}, {tag: "disconnect"} ];
    }
    function test_adapterBatchRejectsMalformedAndLostOutcomes(data) {
        const panel = makePanel();
        const edits = panel.controller.adapterEdits;
        const backend = findChild(panel.controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "Saved name");
        edits.edit("adapter", "pairableTimeout", 120);
        verify(edits.saveBatch("adapter"));
        const response = batchReply("adapter", adapterCalls()[0].params.changes);
        const batch = response.data.adapter_batch;
        if (data.tag === "missing") delete response.data.adapter_batch;
        if (data.tag === "wrong-key") batch.key = "another-adapter";
        if (data.tag === "wrong-value") batch.outcomes[0].value = "Other name";
        if (data.tag === "duplicate") batch.outcomes[1] = batch.outcomes[0];
        if (data.tag === "unknown-state") batch.outcomes[0].state = "accepted";
        if (data.tag === "disconnect") {
            backend.resetTransportState();
            panel.controller.handleTransportFailure("Disconnected");
        } else {
            backend.acceptSharedResponse("adapter-batch", response, "");
        }
        verify(!edits.draft("adapter").pending);
        compare(edits.draft("adapter").fields.alias, "Saved name");
        compare(edits.draft("adapter").fields.pairableTimeout, 120);
        verify(edits.draft("adapter").error.length > 0);
        backend.finish("adapter-batch", batchReply("adapter", {alias: "Saved name", pairable_timeout: 120}), "");
        wait(750);
        compare(adapterCalls().length, 1);
        compare(edits.draft("adapter").fields.alias, "Saved name", "late/unowned replies cannot clear failed drafts");
    }
    Component {
        id: adapterSurfaceComponent
        Ui.ProviderChooserSurface {
            id: surface
            required property Bt.BluetoothController controller
            width: testCase.width
            height: testCase.height
            chooserController: controller
            listComponent: Ui.ChooserListPane {
                chooserController: surface.controller
                powerVisible: false
                resultModel: surface.controller.filteredResults
                rowDelegate: Rectangle { implicitWidth: 300; implicitHeight: 48 }
            }
            detailsComponent: Bt.BluetoothAdapterPage { controller: surface.controller }
        }
    }
    function test_adapterFieldTransactionsSubmitOnlySavedFieldsAndKeepCapturedKey_data() {
        return [{tag: "Enter", saveKey: Qt.Key_Return}, {tag: "Tab", saveKey: Qt.Key_Tab}];
    }
    function test_adapterFieldTransactionsSubmitOnlySavedFieldsAndKeepCapturedKey(data) {
        const panel = makePanel();
        const controller = panel.controller;
        const backend = findChild(controller, "bluetoothBackend");
        controller.uiActive = true;
        const surface = createTemporaryObject(adapterSurfaceComponent, testCase, {controller: controller});
        wait(0);
        backend.pending = ({});
        calls = [];
        controller.adapterSettingsTab = "pairing";
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        keyClick(Qt.Key_Tab);
        const name = findChild(surface.detailsItem, "adapterNameInput");
        tryCompare(surface.detailsNavigation, "currentTarget", name);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_X);
        wait(750);
        compare(adapterCalls().length, 0, "typing is not a submission");
        keyClick(Qt.Key_Escape);
        compare(name.text, "Adapter");
        compare(adapterCalls().length, 0);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_A, Qt.ControlModifier);
        keyClick(Qt.Key_B);
        keyClick(data.saveKey);
        compare(adapterCalls().length, 1);
        compare(adapterCalls()[0].params, {key: "adapter", changes: {alias: "b"}});
        controller.adapters = [{key: "other", alias: "Other radio", powered: true}];
        surface.destroy();
        wait(0);
        backend.acceptSharedResponse("adapter-batch", batchReply("adapter", {alias: "b"}), "");
        compare(Object.keys(controller.adapterEdits.draft("adapter").fields).length, 0);
        compare(Object.keys(controller.adapterEdits.draft("other").fields).length, 0);
        wait(750);
        compare(adapterCalls().length, 1);
    }
    function test_adapterTimeoutSaveAndDiscard_data() {
        return [{tag: "discoverable", field: "discoverable_timeout"},
            {tag: "pairable", field: "pairable_timeout"}];
    }
    function test_adapterTimeoutSaveAndDiscard(data) {
        const panel = makePanel();
        const controller = panel.controller;
        const backend = findChild(controller, "bluetoothBackend");
        controller.uiActive = true;
        const surface = createTemporaryObject(adapterSurfaceComponent, testCase, {controller: controller});
        wait(0);
        backend.pending = ({});
        calls = [];
        controller.adapterSettingsTab = "pairing";
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        const slider = findChild(surface.detailsItem, data.tag + "Timeout");
        for (let i = 0; i < 8 && surface.detailsNavigation.currentTarget !== slider; ++i)
            keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget, slider);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(slider.value, 30);
        wait(750);
        compare(adapterCalls().length, 0);
        keyClick(Qt.Key_Escape);
        compare(slider.value, 0);
        compare(adapterCalls().length, 0);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        compare(adapterCalls().length, 1);
        const changes = {[data.field]: 30};
        compare(adapterCalls()[0].params, {key: "adapter", changes: changes});
        backend.acceptSharedResponse("adapter-batch", batchReply("adapter", changes), "");
        surface.destroy();
        wait(0);
    }
    function test_renameAcknowledgementAndDisconnectKeepCorrectState() {
        const panel = makePanel();
        const controller = panel.controller;
        verify(controller.renameSelected("New name"));
        const snapshot = {
            radio: controller.radio,
            adapters: controller.adapters,
            devices: [Object.assign({}, controller.selectedDevice, {
                    name: "New name",
                    alias: "New name"
                })]
        };
        controller.handleOperationEvent({
            request_id: "rename-1",
            device_key: "buds",
            operation: "set-alias",
            state: "completed",
            snapshot: snapshot
        });
        compare(controller.nameEdits.draft("buds"), null);
        compare(findChild(panel.page, "deviceNameInput").text, "New name");
        findChild(controller, "bluetoothBackend").pending = ({});
        verify(controller.renameSelected("Keep on disconnect"));
        findChild(controller, "bluetoothBackend").failSharedTransport("Disconnected");
        const draft = controller.nameEdits.draft("buds");
        compare(draft.value, "Keep on disconnect");
        verify(draft.dirty && !draft.pending && draft.error.length > 0);
    }
    Component {
        id: deviceDetailsComponent
        Bt.BluetoothDeviceDetails {
            uiScale: 1
        }
    }
    function findButton(item, label) {
        if (item.label === label && typeof item.clicked === "function")
            return item;
        for (const child of item.children || []) {
            const found = findButton(child, label);
            if (found)
                return found;
        }
        return null;
    }
    function test_policyResetIsScopedToDeviceOverrides() {
        const panel = makePanel();
        const controller = panel.controller;
        const details = createTemporaryObject(deviceDetailsComponent, panel, {
            controller: controller,
            width: 720,
            height: 1000
        });
        verify(details !== null);
        const reset = findButton(details, "Reset");
        verify(reset !== null);
        verify(reset.visible);
        const forget = findButton(details, "Forget");
        verify(forget !== null && forget.visible);
        compare(reset.parent, forget.parent);
        compare(findChild(panel.page, "restoreDeviceName").accessibleName, "Restore original name");
        reset.clicked();
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.device.policy.update");
        compare(calls[0].params.key, "buds");
        for (const field of ["reconnect_on_resume", "trust_after_pair", "power_on_connect", "wait_for_services", "fast_pair_controls_enabled", "audio_route_on_connect", "preferred_audio_profile_key"])
            compare(calls[0].params[field], null);
        verify(!controller.triggerDetailAction("reset-policy"));
        compare(calls.length, 1);
    }
}
