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
    function test_operationLookupPreservesFirstMatchAndEmptyGuard() {
        const controller = makePanel().controller;
        controller.applyRequestSnapshot({operations: {active: [
            {request_id: "first", device_key: "buds", operation: "connect", state: "running"},
            {request_id: "second", device_key: "buds", operation: "connect", state: "queued"},
            {request_id: "empty", device_key: "", operation: "connect", state: "running"}
        ]}});
        compare(controller.operationForDevice("buds").request_id, "first");
        compare(controller.operationForDevice("unknown"), null);
        compare(controller.operationForDevice(""), null);
        compare(calls.length, 0, "Snapshot lookup never replays operations");
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
    function test_audioProfileAppliesThenRemembersOriginalDevice() {
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
        profile.selected("aac");
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.audio.setProfile");
        compare(calls[0].params.device_key, "buds");
        compare(calls[0].params.profile_key, "aac");
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
                ]
            }
        }, "");
        compare(calls.length, 2);
        compare(calls[1].method, "bluetooth.device.policy.update");
        compare(calls[1].params.key, "buds");
        compare(calls[1].params.preferred_audio_profile_key, "aac");
        verify(backend.requestRunning);
        backend.acceptSharedResponse("audio-profile-policy", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {message: "Permission denied"}
        }, "");
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
    function test_adapterDraftsOnlyClearAfterAcknowledgement() {
        const panel = makePanel();
        const controller = panel.controller;
        const edits = controller.adapterEdits;
        const backend = findChild(controller, "bluetoothBackend");
        edits.edit("adapter", "alias", "My adapter");
        edits.edit("adapter", "discoverableTimeout", 120);
        verify(edits.saveNext("adapter"));
        compare(edits.draft("adapter").fields.alias, "My adapter");
        backend.acceptSharedResponse("adapter-set-alias", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {
                message: "Permission denied"
            }
        }, "");
        const previousCalls = calls.length;
        wait(750);
        compare(calls.length, previousCalls);
        const page = createTemporaryObject(adapterPageComponent, panel, {
            controller: controller,
            width: 600,
            height: 900
        });
        wait(0);
        compare(findChild(page, "adapterNameInput").text, "My adapter");
        findChild(page, "retryAdapterSettings").clicked();
        compare(calls[calls.length - 1].params.alias, "My adapter");
        backend.acceptSharedResponse("adapter-set-alias", {
            protocol: "bt-api",
            version: 1,
            ok: true,
            data: {
                snapshot: {
                    radio: controller.radio,
                    devices: controller.allDevices,
                    adapters: [
                        {
                            key: "adapter",
                            alias: "My adapter",
                            powered: true
                        }
                    ]
                }
            }
        }, "");
        wait(0);
        compare(edits.draft("adapter").fields.alias, undefined);
        compare(calls[calls.length - 1].params.operation, "set-discoverable-timeout");
        compare(calls[calls.length - 1].params.timeout, 120);
        backend.acceptSharedResponse("adapter-set-discoverable-timeout", {
            protocol: "bt-api",
            version: 1,
            ok: true,
            data: {
                snapshot: {
                    radio: controller.radio,
                    devices: controller.allDevices,
                    adapters: [
                        {
                            key: "adapter",
                            alias: "My adapter",
                            powered: true,
                            discoverable_timeout: 120
                        }
                    ]
                }
            }
        }, "");
        compare(Object.keys(edits.draft("adapter").fields).length, 0);
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
        id: namePanelComponent
        Ui.PanelSurface {
            id: namePanel
            required property Bt.BluetoothController controller
            chooserController: controller
            Bt.BluetoothDeviceActions {
                width: parent.width
                controller: namePanel.controller
            }
        }
    }
    function test_restoreOriginalNameIsEmbeddedAndKeepsCommandGuards() {
        failOnWarning(/.*/);
        const panel = makePanel();
        panel.page.visible = false;
        const controller = panel.controller;
        controller.uiActive = true;
        const backend = findChild(controller, "bluetoothBackend");
        const device = Object.assign({}, controller.selectedDevice, {name: "My buds", alias: "My buds", remote_name: "Buds"});
        const snapshot = {radio: controller.radio, adapters: controller.adapters, devices: [device]};
        controller.applySnapshot(snapshot);
        const surface = createTemporaryObject(namePanelComponent, panel, {controller: controller});
        verify(surface !== null);
        wait(0);
        backend.pending = ({});
        calls = [];
        const field = findChild(surface, "deviceNameInput");
        const restore = findChild(surface, "restoreDeviceName");
        compare(restore.parent, field, "restore is inside the shared name editor, not a separate labeled row");
        compare(restore.label, "");
        compare(restore.accessibleName, "Restore original name");
        compare(restore.accessKey, "O");
        verify(restore.visible && restore.enabled);
        verify(surface.detailsNavigation.targets.indexOf(restore) < 0);
        for (const width of [360, 720]) {
            panel.width = width;
            verify(waitForPolish(surface.Window.window));
            const point = restore.mapToItem(field, 0, 0);
            verify(point.x >= 0 && point.x + restore.width <= field.width);
            verify(point.y >= 0 && point.y + restore.height <= field.height);
            verify(findChild(field, "fieldInput").rightPadding >= restore.width);
        }
        surface.detailsNavigation.focusContent(true);
        compare(surface.detailsNavigation.currentTarget, field);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        compare(field.text, "My budsx");
        compare(calls.length, 0, "typing is still a local draft");
        keyClick(Qt.Key_Escape);
        compare(field.text, "My buds");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        verify(!restore.activeFocus, "restore never joins field traversal");
        compare(calls.length, 0, "Tab never activates restore");
        mouseClick(restore, restore.width / 2, restore.height / 2);
        compare(calls.length, 1);
        compare(calls[0].params.operation, "reset-alias");
        compare(calls[0].params.key, "buds");
        verify(!restore.enabled && restore.visible, "busy keeps the icon visible but guarded");
        compare(field.text, "My buds", "restore waits for the authoritative name");
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(calls.length, 1, "busy keyboard command cannot resubmit");
        const acknowledged = Object.assign({}, snapshot, {devices: [Object.assign({}, device, {name: "Buds", alias: "Buds"})]});
        backend.acceptSharedResponse("device-reset-alias", {protocol: "bt-api", version: 1, ok: true, data: {snapshot: acknowledged}}, "");
        tryCompare(field, "text", "Buds");
        verify(!restore.enabled && restore.visible, "already-original name retains a disabled icon");
        controller.applySnapshot(snapshot);
        tryCompare(field, "text", "My buds");
        verify(restore.enabled);
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(calls.length, 2);
        compare(calls[1].params.operation, "reset-alias");
        backend.pending = ({});
        controller.nameEdits.edit("buds", "Unsaved rename");
        verify(!restore.enabled, "existing domain drafts still block restore");
        controller.nameEdits.discard("buds");
        controller.applySnapshot(Object.assign({}, snapshot, {devices: [Object.assign({}, device, {remote_name: ""})]}));
        verify(!restore.enabled && restore.visible, "unknown original name cannot be restored");
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
