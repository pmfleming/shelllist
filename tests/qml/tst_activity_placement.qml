import QtQuick
import QtTest
import Shelllist.Activity as Activity
import Shelllist.Ui as Ui
import "../../qml/Shelllist/Io/HyprlandWorkArea.js" as WorkArea

TestCase {
    id: testCase
    name: "ActivityPlacement"

    Component { id: activityComponent; Activity.ActivityController {} }
    Component { id: timeWeatherComponent; Activity.TimeWeatherController {} }
    Component { id: notificationsComponent; Activity.NotificationController {} }

    function snapshot() {
        return {
            monitors: [
                { id: 0, name: "eDP-1", description: "Laptop panel", focused: true,
                    x: 0, y: 0, width: 1920, height: 1200, scale: 1.25, transform: 0,
                    activeWorkspace: { id: 1, name: "1" }, specialWorkspace: { id: 0 },
                    reserved: [0, 51, 0, 0] },
                { id: 1, name: "DP-1", description: "External display", focused: false,
                    x: 1536, y: 0, width: 3840, height: 2160, scale: 2, transform: 0,
                    activeWorkspace: { id: 3, name: "3" }, reserved: [24, 80, 10, 20] }
            ],
            workspaces: [
                { id: 1, name: "1", windows: 2, hasfullscreen: false },
                { id: 3, name: "3", windows: 0, hasfullscreen: false }
            ],
            gaps: [2, 2, 2, 2], rules: [],
            clients: [
                { address: "a", workspace: { id: 1 }, mapped: true, floating: false, fullscreen: 0 },
                { address: "b", workspace: { id: 1 }, mapped: true, floating: true, fullscreen: 0 }
            ]
        };
    }

    function test_activityOptsIntoWorkspaceBounds() {
        const controller = createTemporaryObject(activityComponent, testCase);
        verify(controller !== null);
        compare(controller.surfaceAlignment, "right");
        verify(controller.surfaceFitsWorkspace);
        compare(controller.surfaceTopInset, 0);
        compare(controller.surfaceBottomInset, 0);
    }

    function test_centeredPopupsKeepRatioHeight_data() {
        return [
            { tag: "time-weather", component: timeWeatherComponent },
            { tag: "notifications", component: notificationsComponent }
        ];
    }

    function test_centeredPopupsKeepRatioHeight(data) {
        const controller = createTemporaryObject(data.component, testCase);
        verify(controller !== null);
        compare(controller.surfaceAlignment, "center");
        verify(!controller.surfaceFitsWorkspace);
        compare(controller.surfaceTopInset, 0);
        compare(controller.surfaceBottomInset, 0);
        compare(controller.surfaceHeightRatio, Ui.Theme.popupHeightRatio);
    }

    function test_logicalGeometry_data() {
        return [
            { tag: "fractional-laptop", name: "eDP-1", screen: { x: 0, y: 0, width: 1536, height: 960 },
                expected: { x: 2, y: 53, width: 1532, height: 905, left: 2, top: 53, right: 2, bottom: 2 } },
            { tag: "hidpi-negative-origin", name: "DP-1", screen: { x: -1920, y: -100, width: 1920, height: 1080 },
                expected: { x: -1894, y: -18, width: 1882, height: 976, left: 26, top: 82, right: 12, bottom: 22 } },
            { tag: "portrait", name: "DP-1", screen: { x: 1536, y: 0, width: 1080, height: 1920 },
                expected: { x: 1562, y: 82, width: 1042, height: 1816, left: 26, top: 82, right: 12, bottom: 22 } }
        ];
    }

    function test_logicalGeometry(data) {
        compare(WorkArea.rectangle(data.screen, WorkArea.insets(snapshot(), data.name)), data.expected);
    }

    function test_reservationsAndConfigurationChange() {
        const state = snapshot();
        state.monitors[0].reserved = [7, 92, 13, 28];
        state.gaps = [4, 8, 12, 16];
        compare(WorkArea.insets(state, "eDP-1"), { left: 23, top: 96, right: 21, bottom: 40 });
        state.gaps = [0, 0, 0, 0];
        compare(WorkArea.insets(state, "eDP-1"), { left: 7, top: 92, right: 13, bottom: 28 });
    }

    function test_workspaceRulesMergeInOrder() {
        const state = snapshot();
        state.rules = [
            { workspaceString: "r[1-4]", gapsOut: [9, 10, 11, 12] },
            { workspaceString: "1", gapsOut: [3, 4, 5, 6] },
            { workspaceString: "1", borderSize: 10 },
            { workspaceString: "2", gapsOut: [80, 80, 80, 80] }
        ];
        compare(WorkArea.insets(state, "eDP-1"), { left: 6, top: 54, right: 4, bottom: 5 });
        // Empty workspaces still use their effective gaps, not another window's geometry.
        compare(WorkArea.insets(state, "DP-1"), { left: 36, top: 89, right: 20, bottom: 31 });
        state.monitors[0].activeWorkspace = { id: 3, name: "3" };
        compare(WorkArea.insets(state, "eDP-1"), { left: 12, top: 60, right: 10, bottom: 11 });
    }

    function test_monitorSelectors() {
        const monitors = snapshot().monitors;
        for (const selector of ["DP-1", "1", "+1", "-1", "r", "desc:External"])
            verify(WorkArea.monitorMatches(selector, monitors[1], monitors), selector);
        verify(WorkArea.monitorMatches("current", monitors[0], monitors));
        verify(!WorkArea.monitorMatches("current", monitors[1], monitors));
        verify(!WorkArea.monitorMatches("l", monitors[1], monitors));
        monitors[1].transform = 1;
        monitors[1].x = 0;
        monitors[1].y = 960;
        verify(WorkArea.monitorMatches("d", monitors[1], monitors));
    }

    function test_dynamicSmartGaps() {
        const state = snapshot();
        state.rules = [{ workspaceString: "m[eDP-1] w[t1]", gapsOut: [0, 0, 0, 0] }];
        compare(WorkArea.insets(state, "eDP-1"), { left: 0, top: 51, right: 0, bottom: 0 });
        state.clients[1].floating = false;
        compare(WorkArea.insets(state, "eDP-1"), { left: 2, top: 53, right: 2, bottom: 2 });
        compare(WorkArea.insets(state, "DP-1"), { left: 26, top: 82, right: 12, bottom: 22 });
    }

    function test_namedAndSpecialWorkspaces() {
        const state = snapshot();
        state.workspaces.push({ id: -1337, name: "project:web", windows: 0 });
        state.monitors[0].activeWorkspace = { id: -1337, name: "project:web" };
        state.rules = [
            { workspaceString: "n[true] n[s:project:] n[e:web]", gapsOut: [1, 2, 3, 4] },
            { workspaceString: "name:project:web", gapsOut: [5, 6, 7, 8] },
            { workspaceString: "s[true]", gapsOut: [0, 0, 0, 0] }
        ];
        compare(WorkArea.insets(state, "eDP-1"), { left: 8, top: 56, right: 6, bottom: 7 });
        state.workspaces.push({ id: -99, name: "special:notes", windows: 0 });
        state.monitors[0].specialWorkspace = { id: -99, name: "special:notes" };
        compare(WorkArea.insets(state, "eDP-1"), { left: 0, top: 51, right: 0, bottom: 0 });
    }

    function test_cssGaps() {
        compare(WorkArea.cssGaps("0"), [0, 0, 0, 0]);
        compare(WorkArea.cssGaps("2 4"), [2, 4, 2, 4]);
        compare(WorkArea.cssGaps("2 4 6"), [2, 4, 6, 4]);
        compare(WorkArea.cssGaps("2 4 6 8"), [2, 4, 6, 8]);
        compare(WorkArea.cssGaps(""), null);
        compare(WorkArea.cssGaps(undefined), null);
        compare(WorkArea.cssGaps("invalid"), null);
    }

    function test_snapshotParsing() {
        const state = snapshot();
        state.monitors[0].description = 'Display with } [ " \\ and\nnewline';
        const output = [state.monitors, state.workspaces, state.rules, state.clients,
            { css: "2 2 2 2" }].map(function (part) { return JSON.stringify(part, null, 2); }).join("\n\n\n");
        compare(WorkArea.parseBatch(output), state);
        for (const invalid of ["", output.slice(0, -4), "not running", "[] [] [] [] {}", '[null] [] [] [] {"css":"2"}'] ) {
            let rejected = false;
            try { WorkArea.parseBatch(invalid); } catch (error) { rejected = true; }
            verify(rejected, "Must reject invalid snapshot: " + invalid);
        }
    }

    function test_missingMonitorAndSmallScreen() {
        compare(WorkArea.insets(null, "eDP-1"), null);
        compare(WorkArea.insets(snapshot(), "missing"), null);
        compare(WorkArea.rectangle({ x: 0, y: 0, width: 20, height: 30 },
            { left: 40, top: 40, right: 40, bottom: 40 }),
            { x: 19, y: 29, width: 1, height: 1, left: 19, top: 29, right: 0, bottom: 0 });
    }

    function test_liveGeometryEvents() {
        for (const event of ["workspacev2", "focusedmon", "monitoraddedv2", "monitorremoved",
                "configreloaded", "openlayer", "closelayer", "movewindowv2", "closewindow",
                "changefloatingmode", "fullscreen", "activespecialv2", "pin"])
            verify(WorkArea.geometryEvent(event), event);
        verify(!WorkArea.geometryEvent("activewindow"));
    }
}
