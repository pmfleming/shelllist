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
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
    }
    function cleanup() {
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

    function test_emptySearchWindowDoesNotFlashCatalogWhileRanking() {
        const surface = makeSurface();
        const controller = surface.chooserController;
        const store = controller.selectionModel;
        store.rankRequestsEnabled = false;
        surface.listItem.focusSearch();
        keyClick(Qt.Key_Z);
        compare(controller.filterText, "z");
        store.applyRustRanking(store.searchOwner, store.searchGeneration, []);
        compare(controller.filteredResultsModel.count, 0);
        keyClick(Qt.Key_Z);
        compare(controller.filterText, "zz");
        compare(controller.filteredResultsModel.count, 0, "accepted empty results remain visible while the next query is pending");
        const stale = store.searchGeneration;
        catalog(surface, [{id: "a", title: "Alpha updated"}, {id: "b", title: "Beta"}]);
        compare(controller.filteredResultsModel.count, 0, "catalog refresh must not flash unrelated results either");
        store.applyRustRanking(store.searchOwner, stale, [store.sourceResults[0].key]);
        compare(controller.filteredResultsModel.count, 0, "stale ranking still cannot publish");
        store.applyRustRanking(store.searchOwner, store.searchGeneration, [store.sourceResults[0].key]);
        compare(controller.filteredResultsModel.count, 1);
        verify(surface.listItem.searchFocused);
        keyClick(Qt.Key_A, Qt.ControlModifier); keyClick(Qt.Key_Backspace);
        compare(controller.filteredResultsModel.count, 2, "clearing the query restores the baseline immediately");
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
