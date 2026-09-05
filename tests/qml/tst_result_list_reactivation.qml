pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "ResultListReactivation"
    when: windowShown
    width: 360
    height: 240

    function initTestCase() {
        for (let index = 0; index < 50; index++)
            entries.append({ label: "Entry " + index });
        wait(20);
    }

    function init() {
        controller.uiActive = false;
        selection.selectedIndex = 0;
        listView().positionViewAtBeginning();
        wait(1);
    }

    function listView() {
        return findChild(frame, "resultListView");
    }

    function selectedItemIsVisible(list) {
        const item = list.itemAtIndex(list.currentIndex);
        return !!item && item.y + item.height > list.contentY
            && item.y < list.contentY + list.height;
    }

    function test_reactivationRevealsMiddleSelection() {
        const list = listView();
        selection.selectedIndex = 25;
        tryVerify(function () { return selectedItemIsVisible(list); });
        list.positionViewAtBeginning();
        verify(!selectedItemIsVisible(list));

        controller.uiActive = true;
        tryVerify(function () { return selectedItemIsVisible(list); });
        compare(list.currentIndex, 25);
    }

    ListModel { id: entries }
    Ui.ChooserController { id: controller; selectionModel: selection }
    QtObject {
        id: selection
        property int selectedIndex: 0
        function move(delta) { selectedIndex += delta; }
        function selectFirst() { selectedIndex = 0; }
    }
    Ui.ResultListFrame {
        id: frame
        anchors.fill: parent
        controller: controller
        resultModel: entries
        selectedIndex: selection.selectedIndex
        rowDelegate: Component {
            Rectangle {
                required property int index
                width: ListView.view.width
                height: 40
                color: index === selection.selectedIndex ? "red" : "black"
            }
        }
    }
}
