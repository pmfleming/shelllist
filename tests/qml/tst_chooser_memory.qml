pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import Shelllist.Launcher as Apps

DaemonTestCase {
    id: testCase
    name: "ChooserMemory"
    when: windowShown
    visible: true
    width: 1100
    height: 640
    property var retainedViews: []

    Component {
        id: fixtureFactory
        Ui.ProviderChooserSurface {
            id: surface
            width: testCase.width
            height: testCase.height
            property int edits: 0
            property bool showLevel: true
            property bool levelEnabled: true
            property bool privateNote: false
            chooserController: Ui.ProviderChooserController {
                id: owner
                uiActive: true
                property string detailsTab: "one"
                property list<string> availableTabs: ["one", "two"]
                provider: Core.Provider { providerId: "memory"; displayName: "Memory" }
                viewMemory: Ui.ChooserMemory {
                    controller: owner
                    key: owner.selectedResult ? owner.selectedResult.key : ""
                    tab: owner.detailsTab
                    tabs: owner.availableTabs
                    onRestoreRequested: function (open, tab) {
                        owner.detailsTab = tab;
                        owner.detailsOpen = open;
                    }
                }
                function cycleDetailsTab() { detailsTab = detailsTab === "one" ? "two" : "one"; }
            }
            listComponent: Component {
                Ui.ChooserListPane {
                    chooserController: owner
                    resultModel: owner.filteredResultsModel
                    filterText: owner.filterText
                    powerVisible: false
                    rowDelegate: Component { Rectangle { width: 400; height: 52 } }
                }
            }
            Component {
                id: pageFactory
                Ui.DetailFlickable {
                    objectName: "memoryPage"
                    viewMemory: owner.viewMemory
                    memoryTab: owner.detailsTab
                    Ui.TextField {
                        objectName: "ordinaryNote"
                        password: surface.privateNote
                        width: parent.width
                        text: "This value must not enter presentation memory"
                        onEdited: surface.edits++
                    }
                    Item { width: parent.width; height: 700 }
                    Ui.LabeledValueSlider {
                        objectName: "level"
                        label: "Level"
                        visible: surface.showLevel
                        enabled: surface.levelEnabled
                        width: parent.width
                        height: 48
                        from: 0; to: 100; value: 50; stepSize: 10
                        onEdited: surface.edits++
                    }
                    Item { width: parent.width; height: 600 }
                }
            }
            detailsComponent: Component {
                Item {
                    Loader { anchors.fill: parent; asynchronous: true; active: owner.detailsTab === "one"; sourceComponent: pageFactory }
                    Loader { anchors.fill: parent; asynchronous: true; active: owner.detailsTab === "two"; sourceComponent: pageFactory }
                }
            }
        }
    }
    Component {
        id: applicationsFactory
        Apps.ApplicationContent {
            width: testCase.width
            height: testCase.height
            controller: Apps.ApplicationController {}
        }
    }
    Component {
        id: retainedControllerFactory
        Ui.ProviderChooserController {
            id: retainedOwner
            uiActive: true
            provider: Core.Provider { providerId: "retained"; displayName: "Retained" }
            viewMemory: Ui.ChooserMemory {
                controller: retainedOwner
                key: retainedOwner.selectedResult ? retainedOwner.selectedResult.key : ""
                tab: "one"
                tabs: ["one"]
                onRestoreRequested: function (open, tab) { retainedOwner.detailsOpen = open; }
            }
        }
    }
    Component {
        id: delayedViewFactory
        Ui.ProviderChooserSurface {
            id: delayedSurface
            required property Ui.ProviderChooserController owner
            property bool ready: true
            property int edits: 0
            width: testCase.width
            height: testCase.height
            chooserController: owner
            listComponent: Component {
                Ui.ChooserListPane {
                    chooserController: delayedSurface.owner
                    resultModel: delayedSurface.owner.filteredResultsModel
                    filterText: delayedSurface.owner.filterText
                    rowDelegate: Component { Rectangle { width: 400; height: 52 } }
                }
            }
            detailsComponent: Component {
                Loader {
                    asynchronous: true
                    active: delayedSurface.ready
                    sourceComponent: Component {
                        Ui.DetailFlickable {
                            viewMemory: delayedSurface.owner.viewMemory
                            memoryTab: "one"
                            Ui.TextField {
                                objectName: "delayedNote"
                                width: parent.width
                                text: "Ordinary text"
                                onEdited: delayedSurface.edits++
                            }
                        }
                    }
                }
            }
        }
    }
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
    }
    function cleanup() {
        // Resident controllers outlive their recreated visual trees.
        for (const view of retainedViews)
            view.destroy();
        wait(0);
        retainedViews = [];
        Quickshell.environment = ({});
    }
    function catalog(surface, values) {
        const controller = surface.chooserController;
        controller.replaceProviderResults(controller.provider.resultsFor(values), false);
    }
    function makeSurface() {
        const surface = createTemporaryObject(fixtureFactory, testCase);
        catalog(surface, [{id: "a", title: "Alpha"}, {id: "b", title: "Beta"}]);
        surface.chooserController.viewMemory.synchronize();
        surface.listItem.focusList();
        return surface;
    }
    function select(surface, id) {
        const controller = surface.chooserController;
        surface.listItem.focusList();
        controller.select(controller.filteredResults.findIndex(result => result.id === id));
        tryCompare(controller.viewMemory, "activeKey", controller.selectedResult.key);
        verify(surface.listItem.listFocused, "restoring a result never steals list focus");
    }
    function open(surface) {
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsNavigation.currentTarget !== null);
        verify(surface.listItem.listFocused);
        keyClick(Qt.Key_Tab);
        tryVerify(() => surface.detailsNavigation.browsing);
    }
    function page(surface) {
        tryVerify(() => {
            const item = findChild(surface, "memoryPage");
            return item && item.visible && item.restoredKey === surface.chooserController.viewMemory.activeKey && item.restoredTab === surface.chooserController.viewMemory.activeTab;
        });
        const result = findChild(surface, "memoryPage");
        tryVerify(() => result.contentHeight > result.height);
        return result;
    }
    function inspectSecondTab(surface) {
        open(surface);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(surface.chooserController.viewMemory, "activeTab", "two");
        page(surface);
        tryCompare(surface.detailsNavigation.currentTarget, "objectName", "ordinaryNote");
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget.objectName, "level");
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing);
    }
    function closeInvocation(surface) {
        surface.chooserController.prepareUiDeactivation();
        surface.visible = false;
        testCase.forceActiveFocus();
        surface.chooserController.deactivateUi();
        wait(0);
    }
    function reopenInvocation(surface) {
        surface.visible = true;
        surface.chooserController.activateUiState("");
        surface.chooserController.restoreUiFocus();
    }
    function test_invocationRestoresSearchSelectionOnlyOnce() {
        const surface = makeSurface();
        const controller = surface.chooserController;
        // Ranking transport is exercised separately; this fixture owns focus.
        controller.selectionModel.rankRequestsEnabled = false;
        surface.listItem.focusSearch();
        for (const key of [Qt.Key_A, Qt.Key_B, Qt.Key_C, Qt.Key_D, Qt.Key_E, Qt.Key_F])
            keyClick(key);
        const input = findChild(surface.listItem, "fieldInput");
        input.select(5, 2);
        compare(input.cursorPosition, 2);
        closeInvocation(surface);
        compare(controller.focusMemory.region, "search");
        verify(!JSON.stringify(controller.focusMemory).includes("abcdef"));
        input.deselect();
        input.cursorPosition = 0;
        reopenInvocation(surface);
        tryCompare(input, "selectionEnd", 5);
        verify(surface.listItem.searchFocused);
        compare(input.cursorPosition, 2);
        compare(input.selectionStart, 2);
        keyClick(Qt.Key_X);
        compare(controller.filterText, "abxf");
        controller.restoreUiFocus(); // Late host-ready/visibility callbacks.
        wait(0);
        compare(input.cursorPosition, 3);
        compare(controller.filterText, "abxf");
    }
    function test_resultSwitchKeepsTheLatestNativeSelection() {
        const surface = makeSurface();
        open(surface);
        keyClick(Qt.Key_Return);
        findChild(surface.detailsNavigation.currentTarget, "fieldInput").select(8, 2);
        surface.listItem.pick(1); // Changes identity before transferring focus.
        tryCompare(surface.chooserController.viewMemory, "activeKey", surface.chooserController.selectedResult.key);
        compare(surface.chooserController.selectedResult.id, "b");
        select(surface, "a");
        const input = findChild(findChild(page(surface), "ordinaryNote"), "fieldInput");
        input.cursorPosition = 0;
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        tryVerify(() => surface.detailsNavigation.editing);
        compare(input.cursorPosition, 2);
        compare(input.selectionEnd, 8);
        compare(surface.edits, 0);
    }
    function test_invocationRestoresResultsAndKeyedViewport() {
        const surface = makeSurface();
        const values = Array.from({length: 50}, (_, i) => ({id: "entry" + i, title: "Item " + String(i).padStart(2, "0")}));
        catalog(surface, values);
        const controller = surface.chooserController;
        controller.viewMemory.synchronize();
        const list = findChild(surface.listItem, "resultListView");
        tryCompare(list, "count", 50);
        verify(waitForPolish(surface.Window.window));
        list.contentY = 465;
        const saved = surface.listItem.sessionState().viewport;
        verify(saved.key.length > 0);
        const selectedKey = controller.selectedResult.key;
        closeInvocation(surface);
        catalog(surface, [{id: "new", title: "Aardvark"}].concat(values));
        list.contentY = 0;
        reopenInvocation(surface);
        tryVerify(() => {
            const current = surface.listItem.sessionState().viewport;
            return current && current.key === saved.key;
        });
        compare(surface.listItem.sessionState().viewport.offset, saved.offset);
        verify(surface.listItem.listFocused);
        compare(controller.selectedResult.key, selectedKey, "restoration does not reselect");
        keyClick(Qt.Key_Down);
        verify(waitForPolish(surface.Window.window));
        const item = list.itemAtIndex(controller.selectionModel.selectedIndex);
        verify(item.y >= list.contentY && item.y + item.height <= list.contentY + list.height, "new navigation wins over the bookmark");
    }
    function test_queuedSearchCannotCrossAnInvocationBoundary() {
        const surface = makeSurface();
        open(surface);
        keyClick(Qt.Key_Return);
        const controller = surface.chooserController;
        controller.focusSearchRequested();
        // Close/reopen before the previous invocation's queued request runs.
        controller.deactivateUi();
        surface.visible = false;
        testCase.forceActiveFocus();
        reopenInvocation(surface);
        wait(0);
        tryVerify(() => surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget.objectName, "ordinaryNote");
    }
    function test_invocationRevalidatesDisabledEditors() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        closeInvocation(surface);
        surface.levelEnabled = false;
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.browsing && surface.detailsNavigation.currentTarget.objectName === "ordinaryNote");
        verify(!surface.detailsNavigation.editing);
        compare(surface.edits, 0);
    }
    function test_invocationDoesNotRememberPasswords() {
        const surface = makeSurface();
        surface.privateNote = true;
        open(surface);
        keyClick(Qt.Key_Return);
        const field = surface.detailsNavigation.currentTarget;
        field.text = "private-value";
        closeInvocation(surface);
        const location = surface.chooserController.focusMemory.location;
        compare(location.target, "");
        compare(location.selection, null);
        verify(!location.editing);
        verify(!JSON.stringify(surface.chooserController.focusMemory).includes("private-value"));
        field.text = "";
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.browsing);
        verify(!surface.detailsNavigation.editing);
        compare(field.text, "");
    }
    function test_invocationMissingResultFallsBack() {
        const surface = makeSurface();
        open(surface);
        keyClick(Qt.Key_Return);
        closeInvocation(surface);
        catalog(surface, []);
        surface.chooserController.viewMemory.synchronize();
        reopenInvocation(surface);
        tryVerify(() => surface.listItem.searchFocused);
        verify(!surface.chooserController.detailsOpen);
        compare(surface.edits, 0);
    }
    function recreatedView() {
        const owner = createTemporaryObject(retainedControllerFactory, testCase);
        const first = createTemporaryObject(delayedViewFactory, testCase, {owner: owner});
        retainedViews = [first];
        catalog(first, [{id: "a", title: "Alpha"}]);
        owner.viewMemory.synchronize();
        open(first);
        keyClick(Qt.Key_Return);
        verify(first.detailsNavigation.editing);
        findChild(first.detailsNavigation.currentTarget, "fieldInput").select(8, 2);
        closeInvocation(first);
        first.destroy();
        retainedViews = [];
        wait(0);
        const second = createTemporaryObject(delayedViewFactory, testCase, {owner: owner, ready: false});
        retainedViews = [second];
        reopenInvocation(second);
        tryVerify(() => second.detailsNavigation.sessionLocation !== null);
        return second;
    }
    function test_recreatedViewRestoresAnAsynchronousEditor() {
        const surface = recreatedView();
        surface.ready = true;
        tryVerify(() => surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget.objectName, "delayedNote");
        const input = findChild(surface.detailsNavigation.currentTarget, "fieldInput");
        compare(input.cursorPosition, 2);
        compare(input.selectionEnd, 8);
        compare(surface.edits, 0);
        testCase.forceActiveFocus(); // The compositor may blur before hide.
        closeInvocation(surface);
        compare(surface.chooserController.focusMemory.region, "details");
        verify(surface.chooserController.focusMemory.location.editing);
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.editing);
    }
    function test_newNavigationCancelsDeferredEditorRestoration() {
        const surface = recreatedView();
        surface.chooserController.focusSearchRequested();
        tryVerify(() => surface.listItem.searchFocused);
        surface.ready = true;
        tryVerify(() => findChild(surface, "delayedNote") !== null);
        surface.chooserController.restoreUiFocus();
        wait(0);
        verify(surface.listItem.searchFocused);
        verify(!surface.detailsNavigation.editing);
        compare(surface.edits, 0);
    }
    function test_closureFencesDeferredRestoration() {
        const surface = recreatedView();
        closeInvocation(surface);
        surface.ready = true;
        surface.chooserController.restoreUiFocus();
        tryVerify(() => findChild(surface, "delayedNote") !== null);
        verify(!surface.detailsNavigation.activeFocus);
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget.objectName, "delayedNote");
        compare(surface.edits, 0);
    }
    function test_itemsRememberTabScrollAndEditorWithoutStealingFocus() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        const scroll = page(surface).contentY;
        verify(scroll > 0);
        select(surface, "b");
        verify(surface.chooserController.detailsOpen, "new items preserve surface expansion");
        open(surface);
        compare(surface.chooserController.detailsTab, "one");
        page(surface).contentY = 123;
        select(surface, "a");
        verify(surface.chooserController.detailsOpen);
        compare(surface.chooserController.detailsTab, "two");
        tryCompare(page(surface), "contentY", scroll);
        verify(surface.listItem.listFocused);
        compare(surface.edits, 0);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        tryVerify(() => surface.detailsNavigation.editing);
        compare(surface.detailsNavigation.currentTarget.objectName, "level");
        compare(surface.edits, 0, "restoration cannot dispatch an edit");
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        select(surface, "b");
        compare(surface.chooserController.detailsTab, "one");
        tryCompare(page(surface), "contentY", 123);
    }
    function test_immediateRowToggleUsesTheNewIdentity() {
        const surface = makeSurface();
        open(surface);
        surface.listItem.toggleDetails(1);
        compare(surface.chooserController.selectedResult.id, "b");
        verify(!surface.chooserController.detailsOpen, "row toggle changes the shared expansion state");
        compare(surface.chooserController.viewMemory.activeKey, surface.chooserController.selectedResult.key);
        verify(!surface.detailsNavigation.enabled, "closing decoration cannot receive edits");
        select(surface, "a");
        verify(!surface.chooserController.detailsOpen);
        surface.listItem.toggleDetails(1);
        verify(surface.chooserController.detailsOpen);
    }
    function test_missingEditorAndTabFallBackWithoutMutations() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        select(surface, "b");
        surface.showLevel = false;
        select(surface, "a");
        open(surface);
        tryVerify(() => surface.detailsNavigation.browsing);
        compare(surface.detailsNavigation.currentTarget.objectName, "ordinaryNote");
        surface.privateNote = true;
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing);
        select(surface, "b");
        select(surface, "a");
        open(surface);
        verify(surface.detailsNavigation.browsing, "password editor focus is never restored");
        compare(surface.chooserController.viewMemory.pageState("two").target, "");
        surface.listItem.focusList();
        surface.chooserController.availableTabs = ["one"];
        tryCompare(surface.chooserController, "detailsTab", "one");
        verify(surface.listItem.listFocused);
        compare(surface.edits, 0);
    }
    function test_applicationInvocationRestoresAnEditorButNotItsMenu() {
        const content = createTemporaryObject(applicationsFactory, testCase);
        const controller = content.controller;
        wait(0);
        controller.uiActive = true;
        const result = {id: "app.desktop", name: "App", kind: "desktop-application", category: "shell", default_workspace_id: "1", running: false, focused: false, instances: [], desktop_actions: []};
        controller.replaceProviderResults([controller.provider.resultFor(result)], true);
        open(content);
        controller.selectDetailsTab("settings");
        tryVerify(() => content.detailsNavigation.currentTarget && content.detailsNavigation.currentTarget.objectName === "applicationCategory");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Space);
        const category = content.detailsNavigation.currentTarget;
        tryCompare(category.popup, "visible", true);
        closeInvocation(content);
        verify(!category.popup.visible);
        calls = [];
        content.visible = true;
        controller.activateUi("");
        controller.restoreUiFocus();
        tryVerify(() => content.detailsNavigation.editing);
        compare(content.detailsNavigation.currentTarget.objectName, "applicationCategory");
        verify(!category.popup.visible);
        verify(!calls.some(call => call.method === "applications.execute" || call.method === "applications.settings.update"));
        closeInvocation(content);
        content.visible = true;
        controller.activateUiState("");
        category.forceActiveFocus();
        controller.restoreUiFocus();
        category.popup.open(); // A new user menu wins over queued restoration.
        // ComboBox itself owns native menu navigation in the shared style.
        verify(category.activeFocus);
        keyClick(Qt.Key_Down);
        const highlighted = category.highlightedIndex;
        wait(0);
        verify(category.popup.visible && category.activeFocus);
        compare(category.highlightedIndex, highlighted);
        verify(!calls.some(call => call.method === "applications.settings.update"));
        category.popup.close();
    }
    function test_restoredApplicationResourcesRefreshAuthoritativeData() {
        const content = createTemporaryObject(applicationsFactory, testCase);
        const controller = content.controller;
        wait(0);
        controller.uiActive = true;
        const base = {kind: "desktop-application", category: "shell", running: false, focused: false, instances: [], desktop_actions: []};
        controller.replaceProviderResults([
            controller.provider.resultFor(Object.assign({}, base, {id: "a.desktop", name: "App"})),
            controller.provider.resultFor(Object.assign({}, base, {id: "b.desktop", name: "Other"}))
        ], true);
        open(content);
        controller.selectDetailsTab("resources");
        tryVerify(() => calls.some(call => call.method === "applications.history"));
        select(content, "b.desktop");
        calls = [];
        select(content, "a.desktop");
        compare(controller.detailsTab, "resources");
        tryVerify(() => calls.some(call => call.method === "applications.history" && call.params.target_id === "a.desktop"));
        controller.deactivateUi();
        calls = [];
        controller.uiActive = true;
        tryVerify(() => calls.some(call => call.method === "applications.history" && call.params.target_id === "a.desktop"));
        verify(!calls.some(call => call.method === "applications.execute" || call.method === "applications.settings.update"));
    }
}
