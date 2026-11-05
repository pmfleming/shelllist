pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "../../clipboard" as Clip

DaemonTestCase {
    id: testCase
    name: "ClipboardPins"
    when: windowShown
    visible: true
    width: 1150
    height: 800
    property var views: []

    Component { id: controllerFactory; Clip.ClipboardController {} }
    Component { id: contentFactory; Clip.ClipboardContent {} }

    function init() {
        failOnWarning(/.*/);
        calls = [];
    }
    function cleanup() {
        for (const view of views)
            view.destroy();
        views = [];
        Ui.Theme.previewColorScheme = Qt.Unknown;
        wait(0);
    }
    function entry(id, favorite) {
        return {id: id, revision: 1, kind: "text", preview: id, mime: "text/plain", byte_size: 16, favorite: !!favorite, current: false};
    }
    function setup() {
        const controller = createTemporaryObject(controllerFactory, testCase);
        controller.uiActive = true;
        wait(0);
        findChild(controller, "clipboardBackend").pending = ({});
        controller.replaceProviderResults(controller.provider.resultsForEntries([entry("first"), entry("second"), entry("third")]), true);
        const content = createTemporaryObject(contentFactory, testCase, {controller: controller, width: width, height: height});
        verify(content !== null);
        views = views.concat([content]);
        tryVerify(() => content.listItem !== null);
        content.listItem.focusList();
        const list = findChild(content, "resultListView");
        tryCompare(list, "count", 3);
        tryVerify(() => list.itemAtIndex(2) !== null);
        calls = [];
        return {controller: controller, content: content, list: list};
    }
    function actions() { return calls.filter(call => call.method === "clipboard.entry.action"); }
    function dividers(item) {
        let result = item.objectName === "clipboardPinnedDivider" ? [item] : [];
        for (const child of item.children || []) result = result.concat(dividers(child));
        return result;
    }
    function reply(controller, id, data, error) {
        findChild(controller, "clipboardBackend").acceptSharedResponse(id, {
            protocol: "clip-api", version: 2, ok: !error, data: data || {},
            error: error ? {message: error} : undefined
        }, "");
    }
    function clickAvatar(list, index, doubleClick) {
        const avatar = findChild(list.itemAtIndex(index), "resultAvatar");
        verify(avatar !== null);
        if (doubleClick)
            mouseDoubleClickSequence(avatar, avatar.width / 2, avatar.height / 2);
        else
            mouseClick(avatar, avatar.width / 2, avatar.height / 2);
    }

    function test_avatarSelectsThenPinsWithoutPastingAndBodyStillPastes() {
        const ui = setup();
        clickAvatar(ui.list, 1, false);
        compare(ui.controller.selectedEntry.id, "second");
        compare(actions().length, 0, "single click only selects");
        clickAvatar(ui.list, 2, true);
        compare(actions().length, 1);
        compare(actions()[0].params.action, "favorite");
        compare(actions()[0].params.entry_id, "third", "target is the clicked row, not the old selection");
        compare(actions()[0].params.revision, 1);
        compare(ui.controller.selectedEntry.favorite, false, "pending is not acknowledged");
        compare(ui.controller.filteredResults[0].id, "first", "no optimistic reorder");
        reply(ui.controller, "action-favorite", {}, "Favorite limit reached");
        compare(ui.controller.status, "Favorite limit reached");
        compare(ui.controller.selectedEntry.favorite, false);
        const row = ui.list.itemAtIndex(2);
        mouseDoubleClickSequence(row, row.width / 2, row.height / 2);
        compare(actions().length, 2);
        compare(actions()[1].params.action, "paste", "body double-click retains its primary action");
    }

    function test_pinGroupsAcrossPagesKeepOnePassiveDividerAndNativeNavigation() {
        const ui = setup();
        const c = ui.controller;
        c.refresh();
        reply(c, c.activeHistoryQueryId, {_history: {epoch: "pins", revision: 1}, history: {
            entries: [entry("pin-new", true), entry("pin-old", true)], snapshot_revision: "pins-1",
            offset: 0, total: 4, next_cursor: "ordinary"
        }});
        tryCompare(ui.list, "count", 2);
        c.select(1);
        c.loadMoreHistory();
        reply(c, c.activeHistoryQueryId, {_history: {epoch: "pins", revision: 1}, history: {
            entries: [entry("recent"), entry("older")], snapshot_revision: "pins-1", offset: 2, total: 4
        }});
        tryCompare(ui.list, "count", 4);
        compare(c.filteredResults.map(row => row.id), ["pin-new", "pin-old", "recent", "older"]);
        compare(c.selectedEntry.id, "pin-old");
        tryVerify(() => ui.list.itemAtIndex(3) !== null);
        const pinned = ui.list.itemAtIndex(1);
        const ordinary = ui.list.itemAtIndex(2);
        tryVerify(() => dividers(ui.content).filter(item => item.visible && item.height > 0).length === 1);
        const divider = dividers(ui.content).find(item => item.visible && item.height > 0);
        tryCompare(divider, "width", ui.list.width);
        tryVerify(() => ordinary.y - (pinned.y + pinned.height) >= Ui.Theme.spacingMd,
            5000, "the section boundary reserves space for a divider");
        compare(ui.list.itemAtIndex(3).y - (ordinary.y + ordinary.height), ui.list.spacing);
        ui.content.listItem.focusList();
        keyClick(Qt.Key_Down);
        compare(c.selectedEntry.id, "recent", "the divider is not a selectable row");
        keyClick(Qt.Key_Up);
        compare(c.selectedEntry.id, "pin-old");
        keyClick(Qt.Key_Return, Qt.ControlModifier);
        compare(actions().length, 1);
        compare(actions()[0].params.entry_id, "pin-old");
        compare(actions()[0].params.action, "copy");

        // A refreshed group assignment must remove the boundary when only one
        // group remains, without turning its former separator into a result.
        for (const favorite of [false, true]) {
            c.refresh();
            reply(c, c.activeHistoryQueryId, {_history: {epoch: "pins", revision: favorite ? 3 : 2}, history: {
                entries: [entry("pin-new", favorite), entry("pin-old", favorite), entry("recent", favorite)],
                snapshot_revision: favorite ? "pins-3" : "pins-2", offset: 0, total: 3
            }});
            tryCompare(ui.list, "count", 3);
            tryVerify(() => ui.list.itemAtIndex(2) !== null);
            tryVerify(() => dividers(ui.content).every(item => !item.visible || item.height === 0));
            for (let i = 1; i < 3; i++)
                tryVerify(() => ui.list.itemAtIndex(i).y - (ui.list.itemAtIndex(i - 1).y + ui.list.itemAtIndex(i - 1).height) === ui.list.spacing);
            compare(c.selectedEntry.id, "pin-old");
        }
    }

}
