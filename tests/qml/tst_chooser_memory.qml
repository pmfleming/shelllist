pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Core as Core
import Shelllist.Ui as Ui

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
    Component {
        id: incubatingEditorFactory
        Ui.DetailsNavigation {
            id: navigation
            width: 400
            height: 100
            contentItem: pageLoader
            property alias loadPage: pageLoader.active
            property bool restoredBeforeCompletion: false
            property bool pendingBeforeCompletion: false
            property int edits: 0
            Loader {
                id: pageLoader
                anchors.fill: parent
                active: false
                asynchronous: true
                sourceComponent: Ui.TextField {
                    objectName: "incubatingNote"
                    text: ""
                    onEdited: navigation.edits++
                    Component.onCompleted: {
                        // Force a restore attempt while the child exists but its
                        // Loader has not finished initializing the source value.
                        navigation.restoreLocation();
                        navigation.restoredBeforeCompletion = editSession.active;
                        navigation.pendingBeforeCompletion = navigation.pendingMemory;
                        text = "Initialized text";
                    }
                }
            }
        }
    }
    function test_restorationWaitsForLoaderCompletion() {
        const navigation = createTemporaryObject(incubatingEditorFactory, testCase);
        navigation.focusSessionLocation({target: "incubatingNote", editing: true,
            selection: {cursor: 1, anchor: 3}});
        navigation.loadPage = true;
        tryVerify(() => navigation.editing);
        verify(!navigation.restoredBeforeCompletion);
        verify(navigation.pendingBeforeCompletion);
        verify(navigation.contentReady);
        compare(navigation.currentTarget.selectionState(), {cursor: 1, anchor: 3});
        keyClick(Qt.Key_Return);
        compare(navigation.edits, 0, "restoration captures the initialized value, not an empty draft");
        compare(navigation.currentTarget.text, "Initialized text");
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
        const input = findChild(surface.detailsNavigation.currentTarget, "fieldInput");
        compare(input.cursorPosition, 2);
        compare(input.selectionEnd, 8);
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
}
