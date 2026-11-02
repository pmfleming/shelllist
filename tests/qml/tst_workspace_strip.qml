pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui

DaemonTestCase {
    id: tests
    name: "WorkspaceStrip"
    when: windowShown
    visible: true
    width: 400
    height: 100
    Component {
        id: factory
        Bar.WorkspaceStrip {
            width: 220
            screenName: "test-monitor"
            layoutDensity: 1
            controller: Bar.BarController { surfaceRegistry: null }
        }
    }
    function init() { calls = []; failOnWarning(/.*/); }
    function model() {
        return [1,2,3,4,5,6,100].map(id => ({id:id, label:id === 100 ? "Long application origin" : "Workspace",
            icon:id <= 5 ? ["terminal", "language", "code", "music_note", "description"][id - 1] : "workspace",
            number:id > 5 ? String(id) : "", temporary:id > 5, divider_before:id === 6,
            active:id === 100, occupied:id === 6, urgent:id === 6, accessible_name:"Workspace " + id}));
    }
    function make() {
        const strip = createTemporaryObject(factory, tests);
        verify(strip !== null);
        strip.controller.workspaces = {available:true, monitors:[], workspaces:[], lifecycle:{available:true, version:1,
            monitors:{"test-monitor":model()}}};
        wait(0);
        return strip;
    }
    function test_activeBoundsAndFixedAddWithLeftButtonOnly() {
        const strip = make();
        const viewport = findChild(strip, "workspaceViewport");
        const add = findChild(strip, "workspaceAdd");
        compare(strip.items.length, 7);
        verify(viewport.contentWidth > viewport.width, "overflow " + viewport.contentWidth + " / " + viewport.width);
        tryVerify(() => viewport.contentX > 0);
        const active = findChild(strip, "barWorkspace:100");
        compare(active.width, 32);
        const position = active.mapToItem(viewport, 0, 0);
        verify(position.x >= -1 && position.x + active.width <= viewport.width + 1);
        compare(add.x + add.width, strip.width);
        verify(findChild(strip, "workspaceUrgencyAggregate").visible);
        calls = [];
        mouseClick(add, add.width/2, add.height/2, Qt.RightButton);
        mouseClick(add, add.width/2, add.height/2, Qt.MiddleButton);
        compare(calls.length, 0);
        mouseClick(add, add.width/2, add.height/2, Qt.LeftButton);
        const creates = calls.filter(call => call.method === "workspace.command");
        compare(creates.length, 1);
        compare(creates[0].params.command, "create");
        compare(creates[0].params.monitor, "test-monitor");
        compare(strip.activeWorkspaceIndex, 6, "dispatch never guesses selection");
        strip.width = 170;
        wait(0);
        compare(add.x + add.width, strip.width);
    }
    function test_workspacesRenderIconsWithoutInlineTextOrOverlap() {
        const strip = make();
        strip.width = tests.width;
        verify(waitForRendering(strip));
        tryCompare(findChild(strip, "workspaceViewport"), "contentX", 0);
        let previousRight = 0;
        for (const item of strip.items) {
            const button = findChild(strip, "barWorkspace:" + item.id);
            compare(button.width, 32);
            compare(button.accessibleName, item.accessible_name);
            verify(findChild(button, "workspaceOrigin") === null);
            const position = button.mapToItem(strip, 0, 0);
            verify(position.x >= previousRight, "Workspace " + item.id + " overlaps its preceding target");
            previousRight = position.x + button.width;
            if (item.id === 1) {
                verify(findChild(button, "workspaceTerminalGlyph").visible);
            } else {
                const glyph = findChild(button, "workspaceCategoryGlyph");
                verify(glyph.visible);
                compare(glyph.symbol, item.temporary ? "workspaces" : item.icon);
                compare(glyph.font.family, Ui.Theme.symbolFontFamily);
                verify(glyph.implicitWidth <= button.width, "Icon must fit its workspace target");
            }
        }
        verify(previousRight <= findChild(strip, "workspaceAdd").x);
    }
}
