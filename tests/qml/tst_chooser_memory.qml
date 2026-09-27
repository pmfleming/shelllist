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

    Component {
        id: fixtureFactory
        Ui.ProviderChooserSurface {
            id: surface
            width: testCase.width
            height: testCase.height
            keyboardWorkflow: true
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
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
    }
    function cleanup() { Quickshell.environment = ({}); }
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
        tryVerify(() => surface.detailsNavigation.browsing || surface.detailsNavigation.editing);
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
        keyClick(Qt.Key_Down);
        compare(surface.detailsNavigation.currentTarget.objectName, "level");
        keyClick(Qt.Key_Right);
        verify(surface.detailsNavigation.editing);
    }
    function test_itemsRememberTabScrollAndEditorWithoutStealingFocus() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        const scroll = page(surface).contentY;
        verify(scroll > 0);
        select(surface, "b");
        verify(!surface.chooserController.detailsOpen, "uninspected items are list-only");
        open(surface);
        compare(surface.chooserController.detailsTab, "one");
        page(surface).contentY = 123;
        select(surface, "a");
        verify(surface.chooserController.detailsOpen);
        compare(surface.chooserController.detailsTab, "two");
        tryCompare(page(surface), "contentY", scroll);
        verify(surface.listItem.listFocused);
        compare(surface.edits, 0);
        keyClick(Qt.Key_Right);
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
        verify(surface.chooserController.detailsOpen, "the new row opens instead of closing the previous row's view");
        compare(surface.chooserController.viewMemory.activeKey, surface.chooserController.selectedResult.key);
        surface.listItem.toggleDetails(1);
        verify(!surface.chooserController.detailsOpen);
        verify(!surface.detailsNavigation.enabled, "closing decoration cannot receive edits");
        select(surface, "a");
        verify(surface.chooserController.detailsOpen);
    }
    function test_disabledRememberedEditorFallsBackToBrowse() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        select(surface, "b");
        surface.levelEnabled = false;
        select(surface, "a");
        open(surface);
        tryCompare(surface.detailsNavigation.currentTarget, "objectName", "level");
        verify(surface.detailsNavigation.browsing);
        verify(!surface.detailsNavigation.editing);
        keyClick(Qt.Key_Right);
        verify(!surface.detailsNavigation.editing);
        surface.chooserController.select(1);
        tryVerify(() => surface.listItem.listFocused);
        compare(surface.edits, 0);
    }
    function test_explicitCloseChangesOnlyThatResult() {
        const surface = makeSurface();
        open(surface);
        keyClick(Qt.Key_Escape);
        verify(!surface.chooserController.detailsOpen);
        select(surface, "b");
        open(surface);
        select(surface, "a");
        verify(!surface.chooserController.detailsOpen);
        select(surface, "b");
        verify(surface.chooserController.detailsOpen);
    }
    function test_reorderRemovalAndReconnectDoNotEraseInspectedState() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        surface.listItem.focusList();
        const key = surface.chooserController.selectedResult.key;
        catalog(surface, [{id: "a", title: "Zulu"}, {id: "b", title: "Alpha"}]);
        wait(0);
        compare(surface.chooserController.selectedResult.key, key);
        compare(surface.chooserController.detailsTab, "two");
        verify(surface.chooserController.detailsOpen);
        catalog(surface, []);
        tryCompare(surface.chooserController, "detailsOpen", false);
        verify(surface.chooserController.viewMemory.records[key].open);
        catalog(surface, [{id: "a", title: "Alpha"}, {id: "b", title: "Beta"}]);
        tryCompare(surface.chooserController, "detailsOpen", true);
        compare(surface.chooserController.detailsTab, "two");
        verify(surface.listItem.listFocused);
        compare(surface.edits, 0);
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
        keyClick(Qt.Key_Right);
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
    function test_tabsKeepIndependentScrollAndNoFocusOnAsyncLoad() {
        const surface = makeSurface();
        open(surface);
        page(surface).contentY = 100;
        surface.listItem.focusList();
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(surface.chooserController.viewMemory, "activeTab", "two");
        tryCompare(page(surface), "contentY", 0);
        page(surface).contentY = 300;
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(surface.chooserController.viewMemory, "activeTab", "one");
        tryCompare(page(surface), "contentY", 100);
        verify(surface.listItem.listFocused);
        const serialized = JSON.stringify(surface.chooserController.viewMemory.records);
        verify(!serialized.includes("This value"));
        compare(surface.edits, 0);
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
    function test_applicationsRetainSettingsViewAcrossClosureAndCapabilityChange() {
        const content = createTemporaryObject(applicationsFactory, testCase);
        const controller = content.controller;
        wait(0);
        controller.uiActive = true;
        const result = {id: "app.desktop", name: "App", kind: "desktop-application", category: "shell", default_workspace_id: "1", running: false, focused: false, instances: [], desktop_actions: []};
        controller.replaceProviderResults([controller.provider.resultFor(result)], true);
        open(content);
        controller.selectDetailsTab("settings");
        tryCompare(controller.viewMemory, "activeTab", "settings");
        tryVerify(() => content.detailsNavigation.currentTarget && content.detailsNavigation.currentTarget.objectName === "applicationCategory");
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Space);
        tryCompare(content.detailsNavigation.currentTarget.popup, "visible", true);
        keyClick(Qt.Key_Escape);
        content.listItem.focusList();
        controller.replaceProviderResults([controller.provider.resultFor(result), controller.provider.resultFor(Object.assign({}, result, {id: "other.desktop", name: "Other"}))], false);
        select(content, "other.desktop");
        select(content, "app.desktop");
        keyClick(Qt.Key_Right);
        tryVerify(() => content.detailsNavigation.editing);
        compare(content.detailsNavigation.currentTarget.objectName, "applicationCategory");
        verify(!content.detailsNavigation.currentTarget.popup.visible, "remembered editing never reopens a menu");
        keyClick(Qt.Key_Space);
        tryCompare(content.detailsNavigation.currentTarget.popup, "visible", true);
        controller.deactivateUi();
        verify(!content.detailsNavigation.currentTarget.popup.visible, "surface closure closes ordinary menus too");
        content.visible = false;
        wait(0);
        verify(controller.detailsOpen);
        compare(controller.detailsTab, "settings");
        controller.uiActive = true;
        content.visible = true;
        content.listItem.focusList();
        controller.replaceProviderResults([controller.provider.resultFor(Object.assign({}, result, {kind: "desktop-shortcut"}))], false);
        tryCompare(controller, "detailsTab", "application");
        verify(content.listItem.listFocused);
        const key = controller.selectedResult.key;
        controller.clearProviderResults();
        tryCompare(controller, "detailsOpen", false);
        verify(controller.viewMemory.records[key].open, "missing data is not an explicit close");
        controller.replaceProviderResults([controller.provider.resultFor(result)], false);
        tryCompare(controller, "detailsOpen", true);
        verify(content.listItem.listFocused);
        verify(!calls.some(call => call.method === "applications.settings.update"));
    }
}
