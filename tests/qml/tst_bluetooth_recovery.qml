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
    function test_radioSelectionAndPowerAreControlledInBluetoothSettings() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.applySnapshot({
            radio: {
                available: true,
                operational: true,
                powered: true,
                adapter_count: 2
            },
            adapters: [
                {
                    key: "adapter",
                    alias: "Built-in",
                    powered: true
                },
                {
                    key: "usb",
                    alias: "USB",
                    powered: false
                }
            ],
            devices: controller.allDevices
        });
        controller.openBluetoothSettings();
        const page = createTemporaryObject(adapterPageComponent, panel, {
            controller: controller,
            width: 320,
            height: 500
        });
        wait(0);
        const selector = findChild(page, "bluetoothRadioSelector");
        verify(selector.visible && selector.interactive);
        verify(selector instanceof Ui.DropDownList, "radio lists use a scrollable choice, not compressed segments");
        compare(selector.Accessible.name, "Preferred Bluetooth radio");
        const technical = findChild(page, "adapterTechnicalDetails");
        verify(!technical.open);
        const beforeDisclosure = calls.length;
        technical.expanded = true;
        technical.expanded = false;
        compare(calls.length, beforeDisclosure);
        selector.selected("usb");
        compare(calls[calls.length - 1].method, "bluetooth.management.update");
        compare(calls[calls.length - 1].params.preferred_adapter_key, "usb");
        compare(controller.selectedAdapter.key, "usb");
        const backend = findChild(controller, "bluetoothBackend");
        backend.pending = ({});
        const power = findChild(page, "bluetoothRadioPower");
        verify(!power.checked && power.interactive);
        power.clicked();
        compare(calls[calls.length - 1].method, "bluetooth.setPowered");
        compare(calls[calls.length - 1].params.adapter_key, "usb");
        compare(calls[calls.length - 1].params.powered, true);
        backend.pending = ({});
        controller.applySnapshot({
            radio: {
                available: false,
                adapter_count: 0,
                powered: false
            },
            adapters: [],
            devices: []
        });
        verify(!selector.visible && !power.interactive);
        verify(controller.detailsOpen);
        verify(controller.cycleDetailsTab());
        compare(controller.adapterSettingsTab, "pairing");
    }
    Component {
        id: contentComponent
        Bt.BluetoothContent {}
    }
    function sessionContent(adapter, empty) {
        const panel = makePanel();
        panel.page.visible = false;
        const controller = panel.controller;
        controller.uiActive = true;
        if (empty)
            controller.applySnapshot({radio: controller.radio, adapters: controller.adapters, devices: []});
        const content = createTemporaryObject(contentComponent, panel, {controller: controller, width: 1100, height: 900});
        if (adapter) {
            controller.openBluetoothSettings();
            controller.adapterSettingsTab = "pairing";
        } else {
            controller.openDetails();
            controller.detailsTab = "settings";
        }
        const name = adapter ? "adapterNameInput" : "deviceNameInput";
        tryVerify(() => findChild(content, name) !== null);
        content.detailsNavigation.currentTarget = findChild(content, name);
        content.detailsNavigation.focusContent();
        keyClick(Qt.Key_Right);
        verify(content.detailsNavigation.editing);
        findChild(content.detailsNavigation.currentTarget, "fieldInput").select(3, 1);
        return content;
    }
    function closeSession(content) {
        content.controller.prepareUiDeactivation();
        content.visible = false;
        testCase.forceActiveFocus();
        content.controller.deactivateUi();
        wait(0);
    }
    function startSession(content) {
        content.visible = true;
        content.controller.activateUi("");
        content.controller.restoreUiFocus();
        verify(!content.sessionReady);
        tryVerify(() => content.detailsNavigation.browsing);
        verify(!content.detailsNavigation.editing);
    }
    function finishSessionRefresh(content) {
        const controller = content.controller;
        findChild(controller, "bluetoothBackend").acceptSharedResponse("snapshot", {
            protocol: "bt-api", version: 1, ok: true,
            data: {snapshot: {radio: controller.radio, adapters: controller.adapters, devices: controller.allDevices}}
        }, "");
    }
    function test_invocationWaitsForRefreshWithoutReplayingEdits_data() {
        return [{tag: "device", adapter: false}, {tag: "adapter", adapter: true}, {tag: "adapter-empty", adapter: true, empty: true}];
    }
    function test_invocationWaitsForRefreshWithoutReplayingEdits(data) {
        const content = sessionContent(data.adapter, data.empty);
        closeSession(content);
        calls = [];
        startSession(content);
        finishSessionRefresh(content);
        tryVerify(() => content.detailsNavigation.editing);
        compare(content.detailsNavigation.currentTarget.objectName, data.adapter ? "adapterNameInput" : "deviceNameInput");
        const input = findChild(content.detailsNavigation.currentTarget, "fieldInput");
        compare(input.cursorPosition, 1);
        compare(input.selectionEnd, 3);
        verify(calls.every(call => call.method === "bluetooth.snapshot"), "restoration performs no rename, policy or adapter write");
        verify(content.controller.viewMemory.enabled);
        compare(content.controller.viewMemory, data.adapter ? content.controller.adapterMemory : content.controller.deviceMemory);
    }
    function test_adapterPresentationRecordsAreIndependent() {
        const content = sessionContent(true);
        const controller = content.controller;
        const first = controller.selectedAdapter.key;
        const second = Object.assign({}, controller.selectedAdapter, {key: "usb", alias: "Second"});
        controller.adapters = controller.adapters.concat([second]);
        controller.viewMemory.synchronize();
        controller.viewMemory.rememberPage("pairing", {scroll: 42});
        controller.adapterSettingsTab = "general";
        controller.viewMemory.synchronize();
        controller.preferredAdapterKey = "usb";
        controller.viewMemory.synchronize();
        compare(controller.adapterSettingsTab, "general");
        controller.adapterSettingsTab = "pairing";
        controller.viewMemory.synchronize();
        controller.viewMemory.rememberPage("pairing", {scroll: 17});
        controller.preferredAdapterKey = first;
        controller.viewMemory.synchronize();
        compare(controller.adapterSettingsTab, "general");
        compare(controller.viewMemory.pageState("pairing").scroll, 42);
        controller.preferredAdapterKey = "usb";
        controller.viewMemory.synchronize();
        compare(controller.adapterSettingsTab, "pairing");
        compare(controller.viewMemory.pageState("pairing").scroll, 17);
        verify(controller.detailsOpen);
    }
    function test_changedAdapterCannotInheritAnInvocationEditor() {
        const content = sessionContent(true);
        const controller = content.controller;
        closeSession(content);
        controller.applySnapshot({radio: controller.radio, adapters: [{key: "usb", alias: "Other", powered: true}], devices: []});
        content.visible = true;
        controller.activateUi("");
        controller.restoreUiFocus();
        tryVerify(() => content.listItem.searchFocused);
        finishSessionRefresh(content);
        wait(0);
        verify(content.listItem.searchFocused);
        verify(!content.detailsNavigation.editing);
        compare(controller.selectedAdapter.key, "usb");
    }
    function test_newNavigationWinsOverRefreshCompletion() {
        const content = sessionContent(false);
        closeSession(content);
        startSession(content);
        content.cycleRegion(false);
        verify(content.detailsNavigation.browsing);
        const target = content.detailsNavigation.currentTarget.objectName;
        finishSessionRefresh(content);
        content.controller.restoreUiFocus();
        wait(0);
        verify(content.detailsNavigation.browsing);
        compare(content.detailsNavigation.currentTarget.objectName, target);
        verify(!content.detailsNavigation.editing);
    }
    function test_pairingPromptCannotReplaceOrdinaryInvocationFocus() {
        const content = sessionContent(false);
        const controller = content.controller;
        controller.handlePairingEvent({event: "requested", data: {
            request_id: "focus-secret", device_key: "buds", kind: "pin-code", response_required: true
        }});
        controller.pairingInput = "private-value";
        tryVerify(() => controller.pairingPromptOpen && !content.detailsNavigation.activeFocus);
        calls = [];
        closeSession(content);
        compare(controller.pairingInput, "");
        compare(controller.focusMemory.region, "details");
        compare(controller.focusMemory.location.target, "deviceNameInput");
        verify(controller.focusMemory.location.editing);
        verify(!JSON.stringify(controller.focusMemory).includes("private-value"));
        verify(!JSON.stringify(controller.focusMemory).includes("focus-secret"));
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.pairing.respond");
        compare(calls[0].params.accept, false);
        compare(calls[0].params.value, undefined);
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-cancel-focus-secret", {
            protocol: "bt-api", version: 1, ok: true, data: {}
        }, "");
        startSession(content);
        controller.replacePairingPrompts([{request_id: "focus-secret", response_required: true}]);
        verify(!controller.pairingPromptOpen);
        finishSessionRefresh(content);
        tryVerify(() => content.detailsNavigation.editing);
        compare(content.detailsNavigation.currentTarget.objectName, "deviceNameInput");
        const input = findChild(content.detailsNavigation.currentTarget, "fieldInput");
        compare(input.cursorPosition, 1);
        compare(input.selectionEnd, 3);
        verify(!controller.modalPromptOpen);
    }
    function test_deviceViewMemorySurvivesOtherSelectionsAndSensitiveClosure() {
        const panel = makePanel();
        panel.page.visible = false;
        const controller = panel.controller;
        controller.uiActive = true;
        controller.allDevices = controller.allDevices.concat([{
            key: "keyboard", name: "Keyboard", paired: true, connected: false,
            adapter_key: "adapter", capabilities: {}, battery: [], services: [], policy: {}
        }]);
        controller.rebuildResults(false);
        const content = createTemporaryObject(contentComponent, panel, {
            controller: controller, width: 1100, height: 900
        });
        wait(0);
        content.listItem.focusList();
        keyClick(Qt.Key_Right);
        controller.detailsTab = "settings";
        tryCompare(controller.viewMemory, "activeTab", "settings");
        tryVerify(() => findChild(content, "deviceNameInput") !== null);
        content.detailsNavigation.currentTarget = findChild(content, "deviceNameInput");
        content.detailsNavigation.focusContent();
        keyClick(Qt.Key_Right);
        verify(content.detailsNavigation.editing);
        content.listItem.focusList();
        controller.select(controller.filteredResults.findIndex(result => result.payload.key === "keyboard"));
        tryCompare(controller, "detailsOpen", false);
        controller.select(controller.filteredResults.findIndex(result => result.payload.key === "buds"));
        tryCompare(controller, "detailsOpen", true);
        compare(controller.detailsTab, "settings");
        verify(content.listItem.listFocused);
        calls = [];
        keyClick(Qt.Key_Right);
        tryVerify(() => content.detailsNavigation.editing);
        compare(content.detailsNavigation.currentTarget.objectName, "deviceNameInput");
        compare(calls.length, 0, "focus restoration must not rename or apply policy");
        controller.handlePairingEvent({event: "requested", data: {
            request_id: "memory-secret", device_key: "buds", kind: "pin-code", response_required: true
        }});
        controller.pairingInput = "sensitive-value";
        controller.deactivateUi();
        compare(controller.pairingInput, "");
        verify(!JSON.stringify(controller.viewMemory.records).includes("sensitive-value"));
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "settings");
    }
    function test_settingsUseBrowseEditRegionsAndContentFirstTabs() {
        const panel = makePanel();
        panel.page.visible = false;
        panel.controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, panel, {
            controller: panel.controller, width: 1100, height: 900
        });
        content.listItem.focusSearch();
        keyClick(Qt.Key_Return, Qt.AltModifier);
        tryVerify(() => content.detailsNavigation.currentTarget !== null);
        verify(content.detailsNavigation.browsing);
        compare(panel.controller.detailsTab, "adapter");
        let steps = 0;
        while (content.detailsNavigation.currentTarget.objectName !== "bluetoothLoginState" && steps++ < content.detailsNavigation.targets.length)
            keyClick(Qt.Key_Down);
        compare(content.detailsNavigation.currentTarget.objectName, "bluetoothLoginState");
        calls = [];
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Down);
        compare(calls.length, 0, "browsing settings dispatches no changes");
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Right);
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.management.update");
        compare(calls[0].params.launch_state, "enable");
        keyClick(Qt.Key_Escape);
        verify(content.detailsNavigation.browsing);
        findChild(panel.controller, "bluetoothBackend").pending = ({});
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(panel.controller.adapterSettingsTab, "pairing");
        tryCompare(content.detailsNavigation.currentTarget, "objectName", "adapterNameInput");
        verify(content.detailsNavigation.browsing);
        keyClick(Qt.Key_Right);
        verify(content.editingDetails);
        keyClick(Qt.Key_Left);
        verify(content.editingDetails);
        keyClick(Qt.Key_Escape);
        verify(content.detailsNavigation.browsing);
        keyClick(Qt.Key_Escape);
        verify(content.listItem.listFocused);
        verify(!panel.controller.detailsOpen);
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
    function test_failedPairingResponseKeepsPromptAndInput() {
        const panel = makePanel();
        const controller = panel.controller;
        controller.handlePairingEvent({
            event: "requested",
            data: {
                request_id: "a",
                device_key: "buds",
                kind: "passkey",
                response_required: true
            }
        });
        controller.pairingInput = "123456";
        verify(controller.respondPairing(true));
        verify(controller.pairingResponsePending);
        findChild(controller, "bluetoothBackend").acceptSharedResponse("pairing-response", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {
                code: "pairing-response-rejected",
                message: "Try again"
            }
        }, "");
        verify(!controller.pairingResponsePending);
        compare(controller.pairingPrompt.request_id, "a");
        compare(controller.pairingInput, "123456");
        verify(controller.respondPairing(true));
    }
    function test_defaultRouteUsesOpaqueKeys() {
        const controller = makePanel().controller;
        verify(controller.setAudioDefault(controller.selectedSink));
        compare(calls.length, 1);
        compare(calls[0].method, "bluetooth.audio.setDefault");
        compare(calls[0].params.device_key, "buds");
        compare(calls[0].params.endpoint_key, "output");
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
        profile.activated(profile.optionIndex("aac"));
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
            ok: true,
            data: {}
        }, "");
        verify(!backend.requestRunning);
        compare(panel.controller.status, "Bluetooth audio profile updated and remembered");
    }
    function test_failedAudioProfileIsNotRemembered() {
        const panel = makePanel();
        const profile = setupAudioProfile(panel);
        const backend = findChild(panel.controller, "bluetoothBackend");
        profile.activated(profile.optionIndex("unavailable"));
        compare(calls.length, 0);
        profile.selected("aac");
        backend.acceptSharedResponse("audio-set-profile", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {
                message: "Profile unavailable"
            }
        }, "");
        compare(calls.length, 1);
        compare(backend.pendingAudioProfile, null);
        compare(profile.value, "sbc");
        verify(profile.interactive);
        compare(panel.controller.status, "Profile unavailable");
    }
    function test_audioProfileSaveFailureIsReported() {
        const panel = makePanel();
        const profile = setupAudioProfile(panel);
        const backend = findChild(panel.controller, "bluetoothBackend");
        profile.selected("aac");
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
        backend.acceptSharedResponse("audio-profile-policy", {
            protocol: "bt-api",
            version: 1,
            ok: false,
            error: {
                message: "Permission denied"
            }
        }, "");
        compare(profile.value, "aac");
        verify(profile.interactive);
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
    function test_headsetAudioLayoutSurvivesDisconnect() {
        const panel = makePanel();
        const controller = panel.controller;
        const audio = {
            device_key: "buds",
            active_profile_key: "sbc",
            profiles: [
                {
                    key: "sbc",
                    label: "High fidelity",
                    codec: "SBC"
                }
            ],
            sink: {
                key: "output",
                ready: true
            },
            source: {
                key: "input",
                ready: true
            }
        };
        controller.applyAudioSnapshot([audio]);
        const card = findChild(panel.page, "deviceAudio");
        const profile = findChild(panel.page, "currentAudioProfile");
        const codec = findChild(panel.page, "audioCodec");
        const output = findChild(panel.page, "useAudioOutput");
        const input = findChild(panel.page, "useAudioInput");
        // Geometry assertions must wait for nested layouts, not just queued events.
        verify(waitForPolish(panel.Window.window));
        const height = card.height;
        const outputY = output.mapToItem(card, 0, 0).y;
        verify(profile.interactive && output.enabled && input.enabled);
        const connectedDevice = controller.selectedDevice;
        controller.applySnapshot({
            radio: controller.radio,
            adapters: controller.adapters,
            devices: [Object.assign({}, connectedDevice, {
                    connected: false
                })]
        });
        // Even before the audio removal event, stale live routes cannot be used.
        verify(!profile.interactive && !output.enabled && !input.enabled);
        verify(!controller.setAudioDefault(audio.sink));
        verify(!controller.setAudioProfile(audio.profiles[0]));
        controller.applyAudioSnapshot([]);
        verify(waitForPolish(panel.Window.window));
        verify(card.visible && profile.visible && codec.visible && output.visible && input.visible);
        compare(card.height, height);
        compare(output.mapToItem(card, 0, 0).y, outputY);
        compare(profile.value, "sbc");
        compare(profile.optionLabel(profile.currentIndex), "High fidelity");
        compare(codec.text, "Codec: SBC");
        verify(codec.opacity < 1);
        compare(controller.selectedSink.key, undefined);
        compare(controller.selectedSource.key, undefined);
        verify(findChild(panel.page, "audioOutputOnConnect").interactive);
        compare(calls.length, 0);
        controller.applySnapshot({
            radio: controller.radio,
            adapters: controller.adapters,
            devices: [connectedDevice]
        });
        controller.applyAudioSnapshot([audio]);
        verify(profile.interactive && output.enabled && input.enabled);
        compare(codec.opacity, 1);
        // A different device must not inherit this headset's profile or codec.
        controller.applySnapshot({
            radio: controller.radio,
            adapters: controller.adapters,
            devices: [
                {
                    key: "other",
                    paired: true,
                    device_type: "Earbuds",
                    policy: {}
                }
            ]
        });
        controller.applyAudioSnapshot([]);
        compare(profile.value, "");
        compare(codec.text, "Codec: —");
        compare(controller.audioPresentationByDevice.buds, undefined);
    }
    Component {
        id: batteryComponent
        Bt.BluetoothBatteryStatus {
            width: 600
            height: implicitHeight
        }
    }
    function test_overallEarbudBatteryIsNotLostOrAssignedToEachEarbud() {
        const battery = createTemporaryObject(batteryComponent, testCase, {
            device: {
                device_type: "Earbuds",
                connected: true,
                battery: [
                    {
                        component: "main",
                        percentage: 79
                    }
                ]
            }
        });
        verify(battery !== null);
        const overall = findChild(battery, "overallBatteryPercentage");
        verify(overall.visible);
        compare(overall.text, "79%");
        for (const component of ["left", "right"]) {
            verify(findChild(battery, "batteryArtwork-" + component).visible);
            compare(findChild(battery, "batteryPercentage-" + component).text, "—");
        }
        battery.device = {
            device_type: "Headphones",
            connected: false,
            battery: []
        };
        verify(!overall.visible);
        const percentage = findChild(battery, "batteryPercentage-main");
        verify(percentage.visible);
        compare(percentage.text, "—");
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
        compare(findChild(panel.page, "restoreDeviceName").label, "Restore original name");
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
