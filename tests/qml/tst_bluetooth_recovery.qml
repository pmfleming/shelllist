pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import "../../bluetooth" as Bt

DaemonTestCase {
    id: testCase
    name: "BluetoothRecovery"
    when: windowShown
    visible: true
    width: 720
    height: 1000
    property var originalEnvironment
    function init() {
        originalEnvironment = Quickshell.environment;
    }
    function cleanup() {
        Quickshell.environment = originalEnvironment;
    }
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
    function test_connectedBatteryArtworkWaitsForServicesWithoutInventingReadings_data() {
        return [
            {tag: "two-components", components: ["left", "right"], reduced: false},
            {tag: "three-components", components: ["left", "case", "right"], reduced: false},
            {tag: "reduced-motion", components: ["left", "case", "right"], reduced: true}
        ];
    }
    function test_connectedBatteryArtworkWaitsForServicesWithoutInventingReadings(data) {
        Quickshell.environment = Object.assign({}, originalEnvironment, {
            SHELLLIST_NO_ANIMATIONS: data.reduced ? "1" : "0"
        });
        compare(Ui.Theme.noAnimations, data.reduced);
        const panel = makePanel();
        const controller = panel.controller;
        controller.uiActive = true;
        wait(0);
        calls = [];
        function publish(patch) {
            controller.applySnapshot({
                radio: controller.radio, adapters: controller.adapters,
                devices: [Object.assign({}, controller.selectedDevice, patch)]
            });
            wait(0);
        }
        function part(prefix, component) {
            const item = findChild(panel.page, prefix + "-" + component);
            verify(item !== null);
            return item;
        }
        publish({device_type: "Earbuds", components: data.components,
            connected: true, services_resolved: false, battery_live: true,
            battery_last_known: false, battery: [{component: "main", percentage: 100}]});
        const batteryStatus = findChild(panel.page, "bluetoothBatteryStatus");
        const height = batteryStatus.height;
        for (const component of data.components) {
            compare(part("batteryArtwork", component).opacity, 1);
            verify(part("batteryBadge", component).visible);
            compare(part("batteryBadge", component).opacity, 1);
            compare(part("batteryBadge", component).color, Ui.Theme.active);
            verify(!part("batteryPercentage", component).visible);
            const pending = part("batteryPending", component);
            verify(pending.visible);
            compare(pending.spinning, !Ui.Theme.noAnimations);
            verify(pending.parent.Accessible.name.includes("Bluetooth services unresolved"));
            verify(!pending.activeFocus && !pending.activeFocusOnTab);
        }
        compare(findChild(panel.page, "overallBatteryPercentage").text, "100%");
        const pending = part("batteryPending", "left");
        if (!Ui.Theme.noAnimations)
            tryVerify(() => pending.rotation > 0);
        controller.uiActive = false;
        verify(!pending.spinning);
        compare(pending.rotation, 0);
        controller.uiActive = true;
        controller.detailsTab = "settings";
        verify(!pending.visible && !pending.spinning);
        controller.detailsTab = "device";
        compare(pending.spinning, !Ui.Theme.noAnimations);
        compare(batteryStatus.height, height, "waiting keeps the reading slots stable");

        // Each real reading replaces only its own animation, including zero.
        publish({battery: [{component: "left", percentage: 73}]});
        verify(!part("batteryPending", "left").visible);
        compare(part("batteryPercentage", "left").text, "73%");
        verify(part("batteryPending", "right").visible);
        publish({battery: [{component: "left", percentage: 73}, {component: "right", percentage: 0}]});
        verify(!part("batteryPending", "right").visible);
        compare(part("batteryPercentage", "right").text, "0%");

        // No invented progress for resolved-but-unknown/unsupported readings,
        // or old daemons that do not supply readiness.
        for (const resolved of [true, undefined]) {
            publish({services_resolved: resolved, battery: []});
            for (const component of data.components) {
                verify(!part("batteryPending", component).visible);
                compare(part("batteryPercentage", component).text, "—");
                verify(part("batteryBadge", component).visible, "connection is independent of battery support");
            }
        }
        publish({connected: false, services_resolved: false, battery_live: false});
        for (const component of data.components) {
            verify(!part("batteryPending", component).spinning);
            verify(!part("batteryBadge", component).visible);
            compare(part("batteryArtwork", component).opacity, 0.78);
        }
        publish({connected: true, services_resolved: false});
        controller.invalidateBluetooth("Daemon unavailable");
        wait(0);
        verify(!part("batteryPending", "main").visible, "transport loss cannot retain a waiting animation");
        compare(calls.length, 0, "passive battery presentation must not request or replay operations");
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
    }
    Component {
        id: bluetoothContentComponent
        Bt.BluetoothContent {}
    }
    function test_audioProfileSingleNativeOperationPreservesPartialSuccess() {
        const panel = makePanel();
        panel.controller.uiActive = true;
        const content = createTemporaryObject(bluetoothContentComponent, testCase, {
            controller: panel.controller, width: testCase.width, height: testCase.height
        });
        const backend = findChild(panel.controller, "bluetoothBackend");
        wait(0); // Complete startup reconciliation before supplying the audio snapshot.
        backend.pending = ({});
        calls = [];
        setupAudioProfile(panel);
        content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => findChild(content.detailsItem, "currentAudioProfile") !== null);
        tryCompare(panel.controller, "detailsExpansionProgress", 1);
        const profile = findChild(content.detailsItem, "currentAudioProfile");
        // An incubating page exposes its children before Loader.Ready. Wait
        // for shared navigation to discover the field before sending Tab.
        tryCompare(content.detailsNavigation, "contentReady", true);
        tryVerify(() => content.detailsNavigation.availableFields().includes(profile));
        compare(findChild(content.detailsItem, "audioProfileOnConnect"), null);
        compare(profile.value, "sbc");
        profile.activated(profile.optionIndex("unavailable"));
        compare(calls.length, 0);
        profile.selected("aac");
        backend.acceptSharedResponse("audio-set-profile", {
            protocol: "bt-api", version: 2, ok: false,
            error: {message: "Profile unavailable"}
        }, "");
        compare(calls.length, 1, "a rejected profile must not be remembered");
        compare(profile.value, "sbc");
        verify(profile.interactive);
        calls = [];
        content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        tryCompare(content.detailsNavigation, "browsing", true);
        for (let i = 0; i < 8 && content.detailsNavigation.currentTarget !== profile; ++i)
            keyClick(Qt.Key_Tab);
        compare(content.detailsNavigation.currentTarget, profile);
        verify(content.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        verify(profile.editSession.active);
        keyClick(Qt.Key_Down);
        compare(profile.editSession.displayedValue, "aac");
        compare(calls.length, 0, "choice drafts must not write");
        keyClick(Qt.Key_Escape);
        compare(profile.editSession.displayedValue, "sbc");
        verify(!profile.editSession.active);
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
            version: 2,
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
        content.destroy();
        wait(0); // Destroy the surface before its controller-owned fixture.
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
            version: 2,
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
        compare(findChild(newPage, "retryDeviceName"), null);
        compare(findChild(newPage, "discardDeviceName"), null);
        controller.nameEdits.retry("buds");
        compare(calls[calls.length - 1].params.alias, "My renamed buds");
        backend.acceptSharedResponse("device-set-alias", {
            protocol: "bt-api",
            version: 2,
            ok: false,
            error: {
                message: "Adapter unavailable"
            }
        }, "");
        verify(controller.nameEdits.draft("buds").dirty);
        verify(!controller.nameEdits.draft("buds").pending);
        controller.nameEdits.discard("buds");
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
        return { protocol: "bt-api", version: 2, ok: true, data: { adapter_batch: {
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
    function test_adapterAcknowledgementSurvivesMalformedSnapshot() {
        const controller = makePanel().controller, edits = controller.adapterEdits;
        const backend = findChild(controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "Saved name");
        verify(edits.saveBatch("adapter"));
        const response = batchReply("adapter", {alias: "Saved name"});
        response.data.snapshot = {adapters: [null]};
        backend.acceptSharedResponse("adapter-batch", response, "");
        compare(Object.keys(edits.draft("adapter").fields).length, 0);
        compare(edits.requestKey, "");
        verify(controller.status.includes("could not read adapter snapshot"));
        const status = controller.status;
        backend.acceptSharedResponse("adapter-batch", response, "");
        compare(controller.status, status, "an unowned response cannot reapply a snapshot");
        wait(150);
        compare(adapterCalls().length, 1, "a failed observation never replays an acknowledged write");
    }
    function test_adapterBatchRejectsMalformedAndLostOutcomes_data() {
        return [{tag: "wrong-value"}, {tag: "disconnect"}];
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
        if (data.tag === "wrong-value") batch.outcomes[0].value = "Other name";
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
        return [{tag: "Tab", saveKey: Qt.Key_Tab}];
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
}
