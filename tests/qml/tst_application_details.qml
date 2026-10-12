pragma ComponentBehavior: Bound

import QtQuick
import "../../launcher" as Apps

DaemonTestCase {
    id: tests
    name: "ApplicationDetails"
    when: windowShown
    visible: true
    width: 1040
    height: 760

    Component {
        id: factory
        Apps.ApplicationContent {
            width: tests.width
            height: tests.height
            controller: Apps.ApplicationController {
                uiActive: true
                property var dispatched: []
                // Test provider routing with native keys, without real launches.
                function executeProviderAction(request: var, params: var): bool {
                    dispatched = dispatched.concat([params]);
                    return true;
                }
            }
        }
    }
    function init() { failOnWarning(/.*/); calls = []; clientReady = true; }
    function application(kind, count, actionCount) {
        const windows = [];
        const actions = [];
        for (let i = 0; i < count; i++)
            windows.push({id: "window-" + i, title: i ? "A long document name — a project with a long localized title" : "(121) Example window", workspace_id: i ? "4" : "2", focused: i === 0});
        for (let i = 0; i < actionCount; i++)
            actions.push({id: "action-" + i, name: i ? "An arbitrary desktop action with a long localized label " + i : "Open custom project", icon: i ? "" : "open_in_new"});
        return {id: "unknown.desktop", name: "An unfamiliar application", kind: kind || "desktop-application", revision: 7,
            icon: "", running: count > 0, instances: windows, desktop_actions: actions};
    }
    function setApplication(panel, app) {
        panel.controller.replaceProviderResults([panel.controller.provider.resultFor(app)], false);
    }
    function make(app) {
        const panel = createTemporaryObject(factory, tests);
        verify(panel !== null);
        setApplication(panel, app);
        panel.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => findChild(panel, "applicationPage") !== null);
        tryVerify(() => panel.detailsNavigation.contentReady);
        waitForRendering(panel);
        return panel;
    }
    function menu(panel) { return findChild(panel.detailsNavigation, "detailsCommandMenu"); }
    function chooseCommand(panel, name) {
        const list = menu(panel);
        verify(list !== null);
        tryVerify(() => list.activeFocus);
        for (let i = 0; i < list.count; i++) {
            if (list.itemAtIndex(list.currentIndex)?.text === name) {
                keyClick(Qt.Key_Return);
                return;
            }
            keyClick(Qt.Key_Down);
        }
        fail("Missing named command: " + name);
    }
    function test_emptyStatesArePassiveCenteredIcons() {
        const panel = make(application("desktop-application", 0, 0));
        const page = findChild(panel, "applicationPage");
        const windows = findChild(page, "applicationEmptyState");
        const actions = findChild(page, "applicationNoActions");
        const data = findChild(page, "applicationDataDetails");
        for (const state of [windows, actions]) {
            verify(state.visible);
            verify(!findChild(state, "contentStateLabel").visible);
            compare(state.Accessible.name, state.text);
            const glyph = findChild(state, "contentStateGlyph");
            compare(glyph.symbol, state === windows ? "web_asset_off" : "extension_off");
            const center = glyph.mapToItem(page, glyph.width / 2, glyph.height / 2);
            fuzzyCompare(center.x, page.width / 2, 1);
            if (state === actions) {
                verify(center.y > data.y + data.height + glyph.height);
                fuzzyCompare(center.y, (actions.y + page.height) / 2, 1);
            }
        }
        keyClick(Qt.Key_Tab);
        verify(panel.detailsNavigation.highlightedControl === null, "Empty states are not editable stops");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.controller.dispatched.length, 0);
        keyClick(Qt.Key_A, Qt.AltModifier);
        compare(panel.controller.dispatched.length, 1, "Launch remains a header command");
        compare(panel.controller.dispatched[0].action, "activate");

        setApplication(panel, application("desktop-application", 1, 1));
        tryCompare(windows, "visible", false);
        tryCompare(actions, "visible", false);
        setApplication(panel, application("desktop-shortcut", 0, 0));
        tryCompare(windows, "visible", true);
        compare(windows.icon, "open_in_new");
        verify(windows.Accessible.name.indexOf("another application") >= 0);
        verify(!actions.visible);
    }
    function test_reorderedRowsKeepIdentityAndLiveApplicationFallback() {
        const app = application("desktop-application", 2, 0);
        const panel = make(app);
        const updated = application("desktop-application", 2, 0);
        updated.name = "Renamed application";
        updated.instances.reverse();
        updated.instances[0].title = "";
        setApplication(panel, updated);
        verify(waitForPolish(panel.Window.window));
        const row = findChild(panel, "windowRow-window-1");
        tryCompare(row, "index", 0);
        compare(findChild(row, "windowTitle-window-1").text, updated.name);
        mouseClick(findChild(row, "focusWindow-window-1"));
        compare(panel.controller.dispatched.length, 1);
        compare(panel.controller.dispatched[0].window_id, "window-1", "The window ID, not the new row index, owns the command");
        const actions = findChild(row, "windowActions-window-1");
        actions.triggered("focusWindow-window-0");
        compare(panel.controller.dispatched.length, 1, "Stale button IDs cannot become Close for a replacement window");
        mouseClick(findChild(row, "closeWindow-window-1"));
        compare(panel.controller.dispatched[1].action, "close-window");
        compare(panel.controller.dispatched[1].window_id, "window-1");
    }
    function test_altJRetainsAllDesktopAndWindowCommands() {
        const panel = make(application("desktop-application", 1, 12));
        keyClick(Qt.Key_J, Qt.AltModifier);
        chooseCommand(panel, "An arbitrary desktop action with a long localized label 11");
        compare(panel.controller.dispatched.length, 1);
        compare(panel.controller.dispatched[0].desktop_action_id, "action-11");
        compare(panel.controller.dispatched[0].action, "desktop-action");
        compare(panel.controller.dispatched[0].target_id, "unknown.desktop");
        keyClick(Qt.Key_J, Qt.AltModifier);
        chooseCommand(panel, "Close (121) Example window");
        compare(panel.controller.dispatched[1].window_id, "window-0");
    }
}
