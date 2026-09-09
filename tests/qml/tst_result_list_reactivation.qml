pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Core as Core
import Shelllist.Ui as Ui

TestCase {
    name: "ResultListReactivation"
    when: windowShown
    width: 360
    height: 240

    function values(prefix, count) {
        const results = [];
        for (let index = 0; index < count; index++)
            results.push({ providerId: "test", id: prefix + index,
                title: "Entry " + index, score: count - index, actions: [] });
        return results;
    }

    function init() {
        controller.uiActive = false;
        store.clear();
        store.replaceProviderResults("test", values("entry-", 300), true);
        tryCompare(store.visibleModel, "count", 300);
        wait(20);
    }

    function listView() {
        return findChild(frame, "resultListView");
    }

    function selectedItemIsVisible(list) {
        const item = list.itemAtIndex(store.selectedIndex);
        return !!item && item.y >= list.contentY
            && item.y + item.height <= list.contentY + list.height;
    }

    function verifySelection(index) {
        const list = listView();
        compare(store.selectedIndex, index);
        tryCompare(list, "currentIndex", index);
        tryVerify(function () { return selectedItemIsVisible(list); });
    }

    function test_reactivationRevealsSelection() {
        controller.uiActive = true;
        store.selectedIndex = 240;
        verifySelection(240);
        wait(20);
        controller.uiActive = false;
        listView().positionViewAtIndex(0, ListView.Beginning);
        verify(!selectedItemIsVisible(listView()));

        controller.uiActive = true;
        verifySelection(240);
    }

    function test_replacementKeepsLogicalSelection_data() {
        // Cover both lifecycle orderings without a position × timing cross-product.
        return [
            { tag: "hidden-refresh", index: 0, reopenFirst: false },
            { tag: "later-page-refresh-on-reopen", index: 240, reopenFirst: true }
        ];
    }

    function test_replacementKeepsLogicalSelection(data) {
        controller.uiActive = true;
        store.selectedIndex = data.index;
        verifySelection(data.index);
        controller.uiActive = false;
        if (data.reopenFirst) {
            controller.uiActive = true;
            wait(20);
        }

        // Annotation changes the content-derived ID, not the history position.
        // Exercise the real keyed model's insert/move/remove replacement path.
        const edited = values("entry-", 300);
        edited[data.index].id = "edited-image";
        store.replaceProviderResults("test", edited, false);
        // Let Qt finish model layout; a synchronous assertion can pass before
        // ListView moves its current delegate to the bottom of the model.
        wait(20);
        if (!data.reopenFirst)
            controller.uiActive = true;

        verifySelection(data.index);
        compare(store.selected().id, "edited-image");
        compare(store.visibleModel.get(listView().currentIndex).resultData.id, "edited-image");
    }

    function test_progressiveReplacementRevealsSelectionWhenRowArrives() {
        controller.uiActive = true;
        store.selectedIndex = 240;
        verifySelection(240);

        store.replaceProviderResults("test", values("replacement-", 750), false);
        verify(store.visibleModel.count < store.selectedIndex);
        tryCompare(store.visibleModel, "count", 750);
        verifySelection(240);
    }

    function test_scrollingDoesNotForceSelectionBackIntoView() {
        controller.uiActive = true;
        verifySelection(0);
        wait(20);
        listView().positionViewAtIndex(100, ListView.Beginning);
        wait(20);
        compare(listView().currentIndex, 0);
        verify(!selectedItemIsVisible(listView()));
    }

    Core.ProviderRegistry {
        id: registry
        Core.Provider { providerId: "test"; displayName: "Test" }
    }
    Core.ResultStore { id: store; registry: registry; rankRequestsEnabled: false }
    Ui.ChooserController { id: controller; selectionModel: store }
    Ui.ResultListFrame {
        id: frame
        anchors.fill: parent
        visible: controller.uiActive
        controller: controller
        resultModel: store.visibleModel
        selectedIndex: store.selectedIndex
        rowDelegate: Component {
            Rectangle {
                required property int index
                width: ListView.view.width
                height: 40
                color: index === store.selectedIndex ? "red" : "black"
            }
        }
    }
}
