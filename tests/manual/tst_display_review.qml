pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Displays as Displays
import Shelllist.Ui as Ui
import "../qml" as Tests
import "../../displays/DisplayFocusModel.js" as Focus

// Non-mutating visual acceptance fixture. Run explicitly, not in the unit suite.
Tests.DaemonTestCase {
    id: testCase
    name: "DisplayVisualReview"
    when: windowShown
    visible: true
    width: 1040
    height: 780

    Component {
        id: factory
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias content: content
            property alias viewport: viewport
            Displays.DisplayController {
                id: controller
                availableScreenWidth: panel.width
                availableScreenHeight: panel.height
            }
            Ui.SurfaceViewport {
                id: viewport
                width: Math.min(panel.width, controller.currentWindowWidth)
                height: panel.height
                canvasWidth: controller.currentWindowWidth
                Displays.DisplayContent {
                    id: content
                    controller: panel.controller
                }
            }
        }
    }
    function displayState() {
        const values = {};
        for (const group of Focus.groups())
            for (const setting of group.settings)
                values[setting.key] = setting.boolean ? false : 0;
        return {available: true, policy: {prefer_external: false}, status: "extended",
            layout: {saved: {outputs: []}, trial: null},
            focus: {available: true, saved: {}, values: values},
            outputs: [
                {id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: false, focused: true, supported: true, internal: true, mirror_of: "", current_mode: "1920x1200@60.00Hz", modes: [{id: "1920x1200@60.00Hz", width: 1920, height: 1200, rate: 60, size: "1920x1200"}]},
                {id: 1, name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, supported: true, internal: false, mirror_of: "", current_mode: "3840x2160@60.00Hz", modes: [{id: "3840x2160@60.00Hz", width: 3840, height: 2160, rate: 60, size: "3840x2160"}]}
            ]};
    }
    function save(item, name) {
        wait(300);
        verify(waitForPolish(item.Window.window));
        const directory = decodeURIComponent(Qt.resolvedUrl("../../target/display-settings-review/").toString().replace(/^file:\/\//, ""));
        grabImage(item).save(directory + name + ".png");
    }
    function test_render_data() {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_render(data) {
        calls = [];
        Ui.Theme.previewColorScheme = data.scheme;
        const panel = createTemporaryObject(factory, testCase);
        const c = panel.controller;
        c.applyDisplayPolicy(displayState());
        save(panel.viewport, data.tag + "-compact");
        c.openDetails();
        tryVerify(() => panel.content.detailsItem !== null);
        save(panel.viewport, data.tag + "-layout");
        c.uiActive = true;
        c.selectOutput("DP-1");
        const map = findChild(panel, "displayArrangementSummary");
        const pointer = findChild(map, "displayMapPointer-DP-1");
        const start = pointer.mapToItem(map, pointer.width / 2, pointer.height / 2);
        mousePress(pointer, pointer.width / 2, pointer.height / 2);
        mouseMove(map, start.x + 12, start.y);
        const referenceTile = findChild(map, "displayMapScreen-eDP-1");
        mouseMove(map, referenceTile.x + referenceTile.width / 2, referenceTile.y + 2);
        verify(map.dragging && map.candidate && !map.candidate.error);
        save(panel.viewport, data.tag + "-drag-preview");
        keyClick(Qt.Key_Escape);
        mouseRelease(map);
        verify(!c.dirty);
        const three = displayState();
        three.outputs.push(Object.assign({}, three.outputs[1], {id: 2, name: "HDMI-A-1", x: 4096}));
        c.applyDisplayPolicy(three);
        save(panel.viewport, data.tag + "-three-monitors");
        panel.height = 600;
        save(panel.viewport, data.tag + "-short-layout");
        panel.width = 390;
        const target = findChild(panel, "displayPositionReference");
        target.forceActiveFocus();
        save(panel.viewport, data.tag + "-narrow-layout");
        panel.width = 1040;
        panel.height = 780;
        const docked = displayState();
        docked.outputs[0].disabled = true;
        docked.outputs[1].x = 0;
        c.applyDisplayPolicy(docked);
        c.selectOutput("DP-1");
        save(panel.viewport, data.tag + "-disabled-layout");
        c.selectOutput("eDP-1");
        save(panel.viewport, data.tag + "-disabled-selected");
        const mirrored = displayState();
        mirrored.outputs[0].mirror_of = "DP-1";
        mirrored.outputs[1].x = 0;
        c.applyDisplayPolicy(mirrored);
        save(panel.viewport, data.tag + "-mirror-layout");
        c.applyDisplayPolicy(displayState());
        c.selectOutput("DP-1");
        verify(c.placeSelected("above"));
        save(panel.viewport, data.tag + "-draft");
        c.reloadDraft();
        c.openGlobalSettings();
        save(panel.viewport, data.tag + "-focus");
        console.log(data.tag, "Focus content height", findChild(panel, "displayFocusPane").contentHeight);
        for (const category of ["pointer", "keyboard", "applications", "cursor", "diagnostics"]) {
            c.selectFocusPage("focus-" + category);
            save(panel.viewport, data.tag + "-" + category);
        }
        c.selectFocusPage("focus-pointer");
        findChild(panel, "focusHelp-input:follow_mouse_threshold").clicked();
        save(panel.viewport, data.tag + "-help");
        panel.width = 390;
        panel.height = 600;
        save(panel.viewport, data.tag + "-narrow-list");
        const number = findChild(panel, "focusNumber-input:follow_mouse_threshold");
        number.focusInput(false);
        save(panel.viewport, data.tag + "-narrow-editor");
        panel.width = 1040;
        panel.height = 480;
        c.selectFocusPage("focus");
        save(panel.viewport, data.tag + "-short-focus");
        panel.height = 780;
        c.openDetails();
        const trial = displayState();
        trial.layout.trial = {id: "visual-fixture", expires_at: Date.now() / 1000 + 20};
        c.applyDisplayPolicy(trial);
        save(panel.viewport, data.tag + "-trial");
        verify(c.trial !== null);
        verify(findChild(panel, "detailAction:revert").activeFocus, "Revert retains initial trial focus");
        compare(calls.filter(call => call.method !== "bar.snapshot").length, 0, "rendering never mutates real or mocked displays");
    }
}
