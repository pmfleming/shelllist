pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
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
                // Exercise provider routing and actual shared key delivery,
                // without launching real processes from a presentation test.
                function executeProviderAction(request: var, params: var): bool {
                    dispatched = dispatched.concat([params]);
                    return true;
                }
            }
        }
    }

    Component {
        id: iconFactory
        Ui.LabeledAction {
            width: 260
            label: "Arbitrary application action"
            icon: "open_in_new"
            iconSource: Qt.resolvedUrl("fixtures/media-cover.svg")
        }
    }

    function init() { failOnWarning(/.*/); calls = []; clientReady = true; }
    function test_suppliedIconAndNeutralFallbackKeepCommandName() {
        const action = createTemporaryObject(iconFactory,tests);
        verify(action !== null);
        const icon = findChild(action,"controlIcon");
        tryCompare(icon,"hasImage",true);
        compare(action.button.Accessible.name,"Arbitrary application action");
        action.iconSource = "";
        tryCompare(icon,"hasImage",false);
        compare(icon.icon,"open_in_new");
        compare(action.button.Accessible.name,"Arbitrary application action");
    }
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
    function test_capabilityDrivenComposition_data() {
        return [
            {tag:"terminal-no-actions",kind:"desktop-application",windows:1,actions:0},
            {tag:"future-many-actions",kind:"desktop-application",windows:3,actions:12},
            {tag:"installed-not-running",kind:"desktop-application",windows:0,actions:2},
            {tag:"launch-only",kind:"desktop-shortcut",windows:0,actions:0},
            {tag:"stale-runtime-window",kind:"runtime-application",windows:0,actions:0}
        ];
    }
    function test_capabilityDrivenComposition(data) {
        const panel = make(application(data.kind,data.windows,data.actions));
        const page = findChild(panel,"applicationPage");
        compare(findChild(panel,"applicationEmptyState").visible, data.windows === 0);
        compare(findChild(panel,"applicationWindowsHeading").visible, data.windows > 0);
        compare(findChild(panel,"applicationActionsHeading").visible, data.actions > 0);
        if (data.windows) {
            compare(findChild(panel,"windowTitle-window-0").text,"(121) Example window");
            compare(findChild(panel,"windowLocation-window-0").text,"2");
            compare(findChild(panel,"windowLocation-window-0").Accessible.name,"Workspace 2");
            verify(findChild(panel,"windowCurrent-window-0").visible);
            const close = findChild(panel,"closeWindow-window-0");
            verify(close.visible && close.width > 0, "Close is directly available");
            compare(close.Accessible.name, "Close (121) Example window");
            compare(close.tone, "danger");
            verify(!close.activeFocusOnTab);
            verify(findChild(panel,"windowCommands-window-0") === null, "No per-window ellipsis");
        }
        keyClick(Qt.Key_Tab);
        tryVerify(() => panel.detailsNavigation.browsing);
        compare(panel.detailsNavigation.availableFields().length,0);
        compare(panel.detailsNavigation.currentTarget,page);
        keyClick(Qt.Key_Tab,Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget,page);
        compare(panel.controller.dispatched.length,0);
        if (data.actions > 6) {
            verify(page.contentHeight > page.height);
            keyClick(Qt.Key_PageDown);
            verify(page.contentY > 0);
        }
    }
    function test_compactRowsAreAlignedAndPassive_data() {
        return [{tag:"default",scale:1}, {tag:"fractional",scale:1.25}];
    }
    function test_compactRowsAreAlignedAndPassive(data) {
        const app = application("desktop-application",2,0);
        app.instances[0].title = "~/Projects";
        app.instances[1].title = "~";
        const panel = make(app);
        findChild(panel,"applicationInstanceList").uiScale = data.scale;
        waitForRendering(panel);
        const first = findChild(panel,"windowRow-window-0");
        const second = findChild(panel,"windowRow-window-1");
        const title = findChild(panel,"windowTitle-window-0");
        const nextTitle = findChild(panel,"windowTitle-window-1");
        const location = findChild(panel,"windowLocation-window-0");
        const current = findChild(panel,"windowCurrent-window-0");
        const focus = findChild(panel,"focusWindow-window-0");
        verify(first.height <= 60 * data.scale, "Single-line row should be approximately 56px scaled, not 99px: " + first.height);
        verify(Math.abs(first.height - second.height) <= 1);
        compare(title.mapToItem(panel,0,0).x,nextTitle.mapToItem(panel,0,0).x);
        verify(Math.abs(title.mapToItem(panel,0,title.height/2).y - location.mapToItem(panel,0,location.height/2).y) <= 1);
        compare(focus.width,Math.round(32 * data.scale));
        compare(focus.height,Math.round(32 * data.scale));
        const close = findChild(panel,"closeWindow-window-0");
        compare(close.width,focus.width);
        compare(close.height,focus.height);
        compare(close.mapToItem(panel,0,0).x - focus.mapToItem(panel,focus.width,0).x,Math.round(8 * data.scale));
        compare(current.symbol,"center_focus_strong");
        compare(current.Accessible.name,"Current window");
        verify(!findChild(panel,"windowCurrent-window-1").visible);
        verify(!findChild(panel,"windowFocusSuccess-window-0").visible,"Live focus alone is not operation success");
        mouseClick(location);
        mouseClick(current);
        compare(panel.controller.dispatched.length,0);
        panel.listItem.focusList();
        keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.availableFields().length,0);
        keyClick(Qt.Key_Tab,Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget,findChild(panel,"applicationPage"));
        mouseClick(focus);
        compare(panel.controller.dispatched[0].action,"focus-window");
        compare(panel.controller.dispatched[0].window_id,"window-0");
        const replacement = application("desktop-application",2,0);
        replacement.instances[0].focused = false;
        replacement.instances[1].focused = true;
        setApplication(panel,replacement);
        tryVerify(() => !findChild(panel,"windowCurrent-window-0").visible);
        verify(findChild(panel,"windowCurrent-window-1").visible,"Current marker follows the snapshot");
    }
    function test_namedAndUnknownWorkspacesAndLongTitles() {
        const app = application("desktop-application",3,0);
        app.instances[0].workspace_name = "Development workspace";
        app.instances[0].title = "~/Projects/shelllist/a-very-long-project-name — development terminal";
        app.instances[1].workspace_id = "12";
        app.instances[2].workspace_id = "";
        const panel = make(app);
        // Narrow the actual information list without changing shared navigation.
        const first = findChild(panel,"windowRow-window-0");
        findChild(panel,"applicationInstanceList").width = 360;
        waitForRendering(panel);
        const title = findChild(panel,"windowTitle-window-0");
        const location = findChild(panel,"windowLocation-window-0");
        compare(location.text,"Development workspace");
        compare(findChild(panel,"windowLocation-window-1").text,"12");
        compare(findChild(panel,"windowLocation-window-2").text,"?");
        compare(findChild(panel,"windowLocation-window-2").Accessible.name,"Workspace unknown");
        verify(title.lineCount > 1);
        verify(location.lineCount > 1);
        verify(first.height > 56);
        const focus = findChild(panel,"focusWindow-window-0");
        verify(title.mapToItem(panel,title.width,0).x <= focus.mapToItem(panel,0,0).x);
        compare(title.text,app.instances[0].title,"Full title is retained");
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
    function test_directCloseAndAdditionalMenuRouteById() {
        const panel = make(application("desktop-application",2,1));
        const close = findChild(panel,"closeWindow-window-0");
        mouseClick(close);
        compare(panel.controller.dispatched.length,1);
        compare(panel.controller.dispatched[0].action,"close-window");
        compare(panel.controller.dispatched[0].window_id,"window-0");
        compare(panel.controller.dispatched[0].expected_revision,7);
        verify(!panel.detailsNavigation.commandMenuOpen, "Direct close never opens a menu");
        keyClick(Qt.Key_J,Qt.AltModifier);
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        compare(menu(panel).count,5,"Each live window command is registered once alongside desktop actions");
        keyClick(Qt.Key_A,Qt.AltModifier);
        compare(panel.controller.dispatched.length,1,"Underlying primary shortcut is blocked");
        keyClick(Qt.Key_Escape);
        tryVerify(() => !panel.detailsNavigation.commandMenuOpen);
        verify(close.activeFocus,"Dismiss restores preceding pointer command focus");
        keyClick(Qt.Key_J,Qt.AltModifier);
        chooseCommand(panel,"Close (121) Example window");
        compare(panel.controller.dispatched.length,2);
        compare(panel.controller.dispatched[1].action,"close-window");
        compare(panel.controller.dispatched[1].window_id,"window-0");
    }
    function test_windowCommandsReuseResponsiveSizing() {
        const panel = make(application("desktop-application",1,0));
        const list = findChild(panel,"applicationInstanceList");
        list.uiScale = 1;
        const row = findChild(panel,"windowActions-window-0");
        // 32px margins + 56px workspace + 16px column gaps + 96px title.
        const stages = [
            {width:272, size:32, gap:8, rows:1},
            {width:268, size:32, gap:4, rows:1},
            {width:262, size:30, gap:2, rows:1},
            {width:258, size:28, gap:2, rows:1},
            {width:257, size:28, gap:2, rows:2}
        ];
        for (const stage of stages) {
            list.width = stage.width;
            verify(waitForPolish(panel.Window.window));
            compare(row.controlHeight,stage.size);
            compare(row.secondaryGap,stage.gap);
            compare(row.secondaryRows,stage.rows);
            compare(row.shownSecondaryCount,2);
            verify(!findChild(row,"surfaceActionMore").visible);
            const close = findChild(row,"closeWindow-window-0");
            verify(close.visible);
            const position = close.mapToItem(row,0,0);
            verify(position.x >= 0 && position.x + close.width <= row.width);
            verify(position.y + close.height <= row.height);
            mouseClick(close);
            compare(panel.controller.dispatched.slice(-1)[0].action,"close-window");
        }
        panel.controller.activeSettingsRequestId = "pending-settings";
        tryCompare(row,"shownSecondaryCount",1,5000,"Only omit disabled commands after exhausting spacing and size");
        verify(findChild(row,"closeWindow-window-0") === null);
        list.width = 272;
        verify(waitForPolish(panel.Window.window));
        tryCompare(row,"shownSecondaryCount",2);
        compare(row.controlHeight,32);
        verify(!findChild(row,"closeWindow-window-0").enabled);
        list.width = 257;
        verify(waitForPolish(panel.Window.window));
        tryCompare(row,"shownSecondaryCount",1);
        panel.controller.activeSettingsRequestId = "";
        tryCompare(row,"shownSecondaryCount",2,5000,"Newly enabled commands return immediately");
        keyClick(Qt.Key_J,Qt.AltModifier);
        chooseCommand(panel,"Close (121) Example window");
        compare(panel.controller.dispatched.length,stages.length + 1);
    }
    function test_altJRetainsAllDesktopAndWindowCommands() {
        const panel = make(application("desktop-application",1,12));
        keyClick(Qt.Key_J,Qt.AltModifier);
        chooseCommand(panel,"An arbitrary desktop action with a long localized label 11");
        compare(panel.controller.dispatched.length,1);
        compare(panel.controller.dispatched[0].desktop_action_id,"action-11");
        compare(panel.controller.dispatched[0].action,"desktop-action");
        compare(panel.controller.dispatched[0].target_id,"unknown.desktop");
        keyClick(Qt.Key_J,Qt.AltModifier);
        chooseCommand(panel,"Close (121) Example window");
        compare(panel.controller.dispatched[1].window_id,"window-0");
    }
    function test_removedWindowCannotRedirectOpenMenu() {
        const panel = make(application("desktop-application",2,0));
        keyClick(Qt.Key_J,Qt.AltModifier);
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_Down); // Select Close for window-0 before its removal.
        const replacement = application("desktop-application",2,0);
        replacement.instances = replacement.instances.slice(1);
        setApplication(panel,replacement);
        tryVerify(() => !panel.detailsNavigation.commandMenuOpen);
        compare(panel.controller.dispatched.length,0);
    }
    function test_busyCommandsCannotDispatchAndLabelsStayPassive() {
        const panel = make(application("desktop-application",1,1));
        mouseClick(findChild(panel,"windowTitle-window-0"));
        compare(panel.controller.dispatched.length,0);
        panel.controller.activeSettingsRequestId = "pending-settings";
        tryCompare(findChild(panel,"focusWindow-window-0"),"enabled",false);
        verify(!findChild(panel,"desktopAction-action-0").enabled);
        const close = findChild(panel,"closeWindow-window-0");
        verify(close.visible && !close.enabled);
        mouseClick(close);
        close.activate();
        findChild(panel,"desktopAction-action-0").button.activate();
        compare(panel.controller.dispatched.length,0);
    }
}
