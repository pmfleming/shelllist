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
        tryVerify(() => surface.detailsNavigation.currentTarget?.objectName === "ordinaryNote");
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
    function test_missingEditorAndTabFallBackWithoutMutations() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        select(surface, "b");
        surface.showLevel = false;
        select(surface, "a");
        open(surface);
        tryVerify(() => surface.detailsNavigation.browsing && surface.detailsNavigation.currentTarget?.objectName === "ordinaryNote");
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
