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
            results.push({
                providerId: "test",
                id: prefix + index,
                title: "Entry " + index,
                score: count - index,
                actions: []
            });
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
        return !!item && item.y >= list.contentY && item.y + item.height <= list.contentY + list.height;
    }

    function verifySelection(index) {
        const list = listView();
        compare(store.selectedIndex, index);
        tryCompare(list, "currentIndex", index);
        tryVerify(function () {
            return selectedItemIsVisible(list);
        });
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

    Core.ProviderRegistry {
        id: registry
        Core.Provider {
            providerId: "test"
            displayName: "Test"
        }
    }
    Core.ResultStore {
        id: store
        registry: registry
        rankRequestsEnabled: false
    }
    Ui.ChooserController {
        id: controller
        selectionModel: store
    }
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
