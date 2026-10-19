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
                property int refreshes: 0
                function refresh() { refreshes++; }
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
    function test_caretsFollowRestoredOwner() {
        const surface = makeSurface();
        surface.listItem.focusSearch();
        const search = findChild(surface.listItem, "fieldInput");
        tryVerify(() => findChild(search, "fieldCursor") !== null);
        const searchCursor = findChild(search, "fieldCursor");
        verify(searchCursor.visible);
        open(surface);
        keyClick(Qt.Key_Return);
        const input = findChild(surface.detailsNavigation.currentTarget, "fieldInput");
        tryVerify(() => findChild(input, "fieldCursor") !== null);
        const editorCursor = findChild(input, "fieldCursor");
        verify(editorCursor.visible);
        verify(!searchCursor.visible);
        closeInvocation(surface);
        verify(!editorCursor.visible);
        verify(!searchCursor.visible);
        reopenInvocation(surface);
        tryVerify(() => input.activeFocus);
        verify(editorCursor.visible);
        verify(!searchCursor.visible, "restored editing must not paint a search caret");
        keyClick(Qt.Key_Escape);
        verify(surface.detailsNavigation.browsing);
        verify(!editorCursor.visible);
        closeInvocation(surface);
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.browsing);
        verify(!editorCursor.visible);
        verify(!searchCursor.visible);
        surface.listItem.focusSearch();
        verify(searchCursor.visible);
        compare(surface.edits, 0);
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
    function test_readinessResumesFocusButNeverRestoresUnsavedValues() {
        const surface = makeSurface();
        inspectSecondTab(surface);
        const field = surface.detailsNavigation.currentTarget;
        keyClick(Qt.Key_Right);
        verify(field.value !== 50);
        compare(surface.edits, 0);
        closeInvocation(surface);
        surface.sessionReady = false;
        reopenInvocation(surface);
        tryVerify(() => surface.detailsNavigation.browsing && surface.detailsNavigation.currentTarget === field);
        compare(field.value, 50, "closing discarded the unsaved preview");
        surface.sessionReady = true;
        tryVerify(() => surface.detailsNavigation.editing);
        compare(field.value, 50, "resuming restores focus, not the prior draft");
        compare(surface.edits, 0);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        compare(surface.edits, 1, "only explicit native save publishes");
    }
}
