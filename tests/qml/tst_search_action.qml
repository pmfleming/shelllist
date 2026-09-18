import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "SearchAction"
    when: windowShown
    visible: true
    width: 640
    height: 100

    Component {
        id: headerComponent
        Ui.ChooserHeader {
            width: 640
            height: 60
            uiScale: 1
            searchActionIcon: ""
            property int actionCount: 0
            property int primaryCount: 0
            onSearchActionRequested: actionCount++
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    primaryCount++;
                    event.accepted = true;
                }
            }
        }
    }

    function test_searchAction_data() {
        return [
            {tag: "return", key: Qt.Key_Return, modifiers: Qt.AltModifier, icon: "", enabled: true, expected: 1},
            {tag: "enter", key: Qt.Key_Enter, modifiers: Qt.AltModifier, icon: "", enabled: true, expected: 1},
            {tag: "keypad", key: Qt.Key_Enter, modifiers: Qt.AltModifier | Qt.KeypadModifier, icon: "", enabled: true, expected: 1},
            {tag: "disabled", key: Qt.Key_Return, modifiers: Qt.AltModifier, icon: "", enabled: false, expected: 0},
            {tag: "absent", key: Qt.Key_Return, modifiers: Qt.AltModifier, icon: "", enabled: true, expected: 0}
        ];
    }

    function test_searchAction(data) {
        const header = createTemporaryObject(headerComponent, testCase, {
            searchActionIcon: data.icon,
            searchActionEnabled: data.enabled,
            filterText: "query"
        });
        verify(header !== null);
        header.focusSearch();
        keyClick(data.key, data.modifiers);
        compare(header.actionCount, data.expected);
        compare(header.primaryCount, 0);
        compare(header.filterText, "query");

        keyClick(data.key);
        compare(header.actionCount, data.expected);
        compare(header.primaryCount, 1);
    }
}
