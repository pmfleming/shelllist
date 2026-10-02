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
                {id: 0, name: "eDP-1", width: 1920, height: 1200, refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0, disabled: false, focused: true, availableModes: ["1920x1200@60.00Hz"]},
                {id: 1, name: "DP-1", width: 3840, height: 2160, refreshRate: 60, x: 1536, y: 0, scale: 1.5, transform: 0, disabled: false, availableModes: ["3840x2160@60.00Hz"]}
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
        c.edit("DP-1", "x", 1700);
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
        verify(findChild(panel, "revertDisplayLayout").activeFocus, "Revert retains initial trial focus");
        compare(calls.filter(call => call.method !== "bar.snapshot").length, 0, "rendering never mutates real or mocked displays");
    }
}
