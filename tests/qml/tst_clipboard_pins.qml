pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "../../clipboard" as Clip
import "../../qml/Shelllist/Ui/MaterialIcons.js" as MaterialIcons

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
    function acknowledge(controller, action, entries) {
        reply(controller, "action-" + action, {operation: {id: "op-" + calls.length, action: action, status: "completed", message: "Updated"}});
        controller.refresh();
        reply(controller, controller.activeHistoryQueryId, {history: {
            snapshot_revision: String(calls.length), entries: entries, total: entries.length,
            offset: 0, next_cursor: ""
        }});
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

    function test_multiplePinsFollowNativeOrderAndUnpinIndependently() {
        const ui = setup();
        clickAvatar(ui.list, 2, true);
        acknowledge(ui.controller, "favorite", [entry("third", true), entry("first"), entry("second")]);
        compare(ui.controller.selectedEntry.id, "third");
        compare(ui.controller.selectedIndex, 0);
        tryVerify(() => ui.list.itemAtIndex(0).entry.favorite);
        verify(ui.list.itemAtIndex(0).accessibleName.includes("Pinned"));
        clickAvatar(ui.list, 2, true);
        compare(actions()[1].params.entry_id, "second");
        acknowledge(ui.controller, "favorite", [entry("second", true), entry("third", true), entry("first")]);
        compare(ui.controller.filteredResults.map(result => result.id), ["second", "third", "first"]);
        compare(ui.controller.filteredResults.filter(result => result.payload.favorite).length, 2);
        clickAvatar(ui.list, 0, true);
        compare(actions()[2].params.action, "unfavorite");
        acknowledge(ui.controller, "unfavorite", [entry("third", true), entry("second"), entry("first")]);
        compare(ui.controller.selectedEntry.id, "second");
        compare(ui.controller.selectedIndex, 1);
        compare(ui.controller.filteredResults[0].payload.favorite, true, "unpinning does not clear other pins");
        compare(ui.controller.selectedEntry.favorite, false);
    }

    function test_pinBadgeIsPassiveQuarterAvatar_data() {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_pinBadgeIsPassiveQuarterAvatar(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        const ui = setup();
        const row = ui.list.itemAtIndex(0);
        const avatar = findChild(row, "resultAvatar");
        const badge = findChild(row, "resultAvatarBadge");
        const glyph = findChild(row, "resultAvatarBadgeGlyph");
        verify(!badge.visible);
        clickAvatar(ui.list, 0, true);
        acknowledge(ui.controller, "favorite", [entry("first", true), entry("second"), entry("third")]);
        tryCompare(badge, "visible", true);
        waitForRendering(ui.content);
        compare(badge.width, avatar.width / 4);
        compare(badge.height, avatar.height / 4);
        compare(badge.x + badge.width, avatar.width);
        compare(badge.y + badge.height, avatar.height);
        compare(glyph.glyph, "push_pin");
        compare(glyph.symbol, "push_pin", "badge uses a semantic icon, not literal text");
        compare(glyph.color, Ui.Theme.mutedText);
        compare(badge.color, Ui.Theme.surfaceRaised);
        verify(!badge.activeFocusOnTab && !glyph.activeFocusOnTab);
        verify(badge.Accessible.ignored && glyph.Accessible.ignored);
        verify(row.accessibleName.includes("Pinned"));
        keyClick(Qt.Key_Down);
        compare(ui.controller.selectedIndex, 1);
        verify(badge.visible, "pin remains visible on unselected rows");
        compare(glyph.color, Ui.Theme.mutedText);
        // The passive badge shares the avatar gesture, not a new command target.
        mouseDoubleClickSequence(badge, badge.width / 2, badge.height / 2);
        compare(actions().length, 2);
        compare(actions()[1].params.action, "unfavorite");
        compare(actions()[1].params.entry_id, "first");
        acknowledge(ui.controller, "unfavorite", [entry("first"), entry("second"), entry("third")]);
        tryCompare(badge, "visible", false);
    }

    function test_expandedButtonAndAltNOnBothTabs() {
        const ui = setup();
        keyClick(Qt.Key_Right);
        tryCompare(ui.controller, "detailsOpen", true);
        let pin = null;
        tryVerify(() => { pin = findChild(ui.content, "detailAction:pin"); return pin !== null && pin.visible && pin.width > 0 && pin.height > 0; });
        waitForRendering(ui.content);
        verify(pin.enabled, "pin does not need a decoded preview");
        compare(pin.accessibleName, "Pin to top");
        compare(pin.icon, "push_pin");
        compare(MaterialIcons.name(pin.icon), "push_pin");
        verify(!pin.activeFocusOnTab);
        mouseClick(pin, pin.width / 2, pin.height / 2);
        compare(actions().length, 1);
        compare(actions()[0].params.action, "favorite");
        tryVerify(() => { pin = findChild(ui.content, "detailAction:pin"); return pin && !pin.enabled; }, 5000, "pending actions cannot be repeated");
        acknowledge(ui.controller, "favorite", [entry("first", true), entry("second"), entry("third")]);
        tryVerify(() => { pin = findChild(ui.content, "detailAction:pin"); return pin && pin.enabled; });
        compare(pin.accessibleName, "Unpin");
        compare(pin.icon, "keep_off");
        compare(MaterialIcons.name(pin.icon), "keep_off");
        ui.content.listItem.focusList();
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(ui.controller, "detailsTab", "info");
        keyClick(Qt.Key_N, Qt.AltModifier);
        compare(actions().length, 2);
        compare(actions()[1].params.action, "unfavorite");
        compare(actions()[1].params.entry_id, "first");
    }

    function test_guardedIconNeverFallsThroughToPaste_data() {
        return ["actionInFlight", "screenshotInFlight", "multiSelectMode", "deleteMenuOpen", "deleteConfirmationOpen", "bulkDeleteConfirmationOpen", "wipeChallenge", "editing", "editBeginPending"].map(guard => ({tag: guard, guard: guard}));
    }
    function test_guardedIconNeverFallsThroughToPaste(data) {
        const ui = setup();
        if (data.guard === "editing" || data.guard === "editBeginPending")
            ui.controller.detailState[data.guard] = true;
        else
            ui.controller[data.guard] = data.guard === "wipeChallenge" ? {id: "wipe"} : true;
        verify(!ui.controller.pinEnabled);
        clickAvatar(ui.list, 0, true);
        compare(actions().length, 0);
        verify(!ui.controller.togglePin(ui.controller.selectedEntry), "controller guard also protects direct commands");
        compare(actions().length, 0);
    }
}
