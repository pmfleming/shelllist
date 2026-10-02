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

    function test_searchBarRetainsEditorAndEmbeddedActions() {
        const header = createTemporaryObject(headerComponent, testCase, {
            width: 425, height: 56,
            filterText: "query", iconActionEnabled: true, icon: "+"
        });
        verify(header !== null);
        wait(0);
        const field = findChild(header, "chooserSearchField");
        const input = findChild(field, "fieldInput");
        const leading = findChild(header, "searchLeadingIcon");
        compare(findChild(header, "searchResultCount"), null, "counts belong in the status bar, not search");
        compare(header.radius, 28);
        compare(field.border.width, 0);
        header.focusSearch();
        compare(String(leading.color), String(Ui.Theme.accent));
        verify(!findChild(field, "focusRing").visible);
        header.restoreSelection({cursor: 2, anchor: 2});
        keyClick(Qt.Key_Left);
        compare(input.cursorPosition, 1);
        header.insertSearchText("X");
        compare(input.text, "qXuery");
        const selection = header.selectionState();
        compare(selection.cursor, 2);
        const action = findChild(header, "fieldTrailingAction");
        verify(action.x >= field.x + field.width);
        mouseClick(action);
        compare(header.actionCount, 1);
        header.searchActionEnabled = false;
        action.Accessible.pressAction();
        compare(header.actionCount, 1);
        const refresh = findChild(header, "chooserRefreshButton");
        verify(refresh.mapToItem(header, refresh.width, 0).x <= header.width);
        verify(field.width >= 48);
    }

    function test_searchAction_data() {
        return [
            {
                tag: "return",
                key: Qt.Key_Return,
                modifiers: Qt.AltModifier,
                icon: "",
                enabled: true,
                expected: 1
            },
            {
                tag: "disabled",
                key: Qt.Key_Return,
                modifiers: Qt.AltModifier,
                icon: "",
                enabled: false,
                expected: 0
            }
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
