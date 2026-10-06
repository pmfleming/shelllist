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
            id: surface
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
            compare(findChild(panel,"windowLocation-window-0").text,"Workspace 2");
            verify(findChild(panel,"windowCurrent-window-0").visible);
            compare(findChild(panel,"closeWindow-window-0").width,0,"Close is named-menu-only");
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
    function test_namedWindowMenuRoutesByIdAndIsModal() {
        const panel = make(application("desktop-application",2,1));
        const more = findChild(panel,"windowCommands-window-0");
        panel.listItem.focusList();
        mouseClick(more);
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        compare(menu(panel).count,2,"Per-window menu contains focus and close only");
        keyClick(Qt.Key_A,Qt.AltModifier);
        compare(panel.controller.dispatched.length,0,"Underlying primary shortcut is blocked");
        keyClick(Qt.Key_Escape);
        tryVerify(() => !panel.detailsNavigation.commandMenuOpen);
        verify(more.activeFocus,"Dismiss restores preceding pointer command focus");
        mouseClick(more);
        chooseCommand(panel,"Close (121) Example window");
        compare(panel.controller.dispatched.length,1);
        compare(panel.controller.dispatched[0].action,"close-window");
        compare(panel.controller.dispatched[0].window_id,"window-0");
        compare(panel.controller.dispatched[0].expected_revision,7);
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
        mouseClick(findChild(panel,"windowCommands-window-0"));
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
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
        findChild(panel,"closeWindow-window-0").activate();
        findChild(panel,"desktopAction-action-0").button.activate();
        compare(panel.controller.dispatched.length,0);
    }
}
