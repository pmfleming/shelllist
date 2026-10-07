pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

DaemonTestCase {
    id: testCase
    name: "ContentState"
    when: windowShown
    visible: true
    width: 1050
    height: 720

    Component {
        id: surfaceFactory
        Ui.ProviderChooserSurface {
            id: surface
            property string readState: "loading"
            property string readText: "Loading items…"
            property string operationStatus: ""
            property int saves: 0
            chooserController: Ui.ProviderChooserController {
                id: owner
                uiActive: true
                providerRankedResults: true
                closeDetailsWithoutSelection: true
                provider: Core.Provider { providerId: "state-test"; displayName: "State test" }
            }
            listComponent: Ui.ChooserListPane {
                chooserController: owner
                resultModel: owner.filteredResultsModel
                filterText: owner.filterText
                emptyIcon: "apps"
                emptyText: surface.readText
                emptyState: surface.readState
                powerVisible: false
                status: surface.operationStatus
                rowDelegate: Ui.ResultRow {
                    id: row
                    required property var resultData
                    listPane: surface.listItem
                    leadingIcon: "apps"
                    Ui.ResultLabel { title: row.resultData.title }
                }
            }
            detailsComponent: Item {
                Ui.TextField {
                    objectName: "stateTestEditor"
                    width: parent.width
                    text: "Saved"
                    onEdited: surface.saves++
                }
            }
        }
    }
    function init(): void { failOnWarning(/.*/); calls = []; }
    // One shared-surface lifecycle replaces per-adapter wording/icon matrices.
    // Domain suites retain owned reads, failure recovery and mutation guards.
    function test_firstRowsDoNotStealFocusAndRefreshDoesNotCommitDrafts(): void {
        const surface = createTemporaryObject(surfaceFactory, testCase);
        tryVerify(() => surface.listItem !== null);
        const list = surface.listItem;
        const owner = surface.chooserController;
        const message = findChild(surface, "resultListEmptyMessage");
        tryCompare(message, "visible", true);
        compare(message.kind, "loading");
        list.focusSearch();
        keyClick(Qt.Key_X);
        compare(owner.filterText, "x");
        const rows = owner.provider.resultsFor([{id: "one", title: "First"}, {id: "two", title: "Second"}]);
        owner.replaceProviderResults(rows, false);
        tryCompare(list, "resultCount", 2);
        verify(list.searchFocused, "first read completion must not take search focus");
        verify(!message.visible && !message.spinning);
        keyClick(Qt.Key_Down);
        verify(list.listFocused);
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null);
        verify(list.listFocused, "expansion remains action-free and keeps list focus");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        const editor = findChild(surface, "stateTestEditor");
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        compare(editor.text, "Savedx");
        surface.readState = "unavailable";
        surface.readText = "Refresh failed";
        surface.operationStatus = "Capturing window…";
        owner.replaceProviderResults(rows.concat(owner.provider.resultsFor([{id: "three", title: "Third"}])), false);
        tryCompare(list, "resultCount", 3);
        verify(!message.visible);
        compare(editor.text, "Savedx");
        compare(surface.saves, 0, "rendering and appending must not commit local edits");
        keyClick(Qt.Key_Escape);
        compare(editor.text, "Saved");
        owner.replaceProviderResults([], false);
        tryCompare(message, "visible", true);
        tryCompare(owner, "detailsOpen", false);
        compare(message.kind, "unavailable");
        compare(message.text, "Refresh failed");
        compare(list.status, "Capturing window…", "placeholder cannot replace an operation's status");
        verify(findChild(message, "contentStateLabel").visible);
        list.focusSearch();
        keyClick(Qt.Key_Tab);
        verify(!message.activeFocus, "empty states never become navigation stops");
        compare(surface.saves, 0);
        compare(calls.length, 0);
    }
}
