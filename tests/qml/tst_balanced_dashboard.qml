pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "ColorContrast.js" as Contrast
import "../../bar/BarApi.js" as BarApi

DaemonTestCase {
    id: testCase
    name: "BalancedDashboard"
    when: windowShown
    visible: true
    width: 1200
    height: 90
    property int previousScheme
    Component {
        id: factory
        Bar.BarContent {
            id: bar
            width: 1200
            height: 51
            screenName: "test"
            property QtObject registry: QtObject {
                property var wifiController: null
                property var bluetoothController: null
                property var notificationState: null
                property var opened: []
                property string timeTab: ""
                function surfaceRequested(name: string): void { opened = opened.concat([name]); }
                function requestTimeWeatherTab(tab: string): void { timeTab = tab; }
            }
            controller: Bar.BarController {
                surfaceRegistry: bar.registry
                battery: ({available: true, percentage: 52, charging: true, plugged: true})
                workspaces: ({monitors: [{name: "test", active_workspace_id: 1}], focused_monitor: "test",
                    active_window: {class_name: "unrelated.application"}, workspaces: [
                        {id: 1, monitor: "test", windows: 1}, {id: 3, monitor: "test", windows: 2},
                        {id: 5, monitor: "test", windows: 0, urgent: true}]})
            }
        }
    }
    function init(): void {
        calls = [];
        previousScheme = Ui.Theme.previewColorScheme;
        failOnWarning(/.*/);
    }
    function cleanup(): void {
        Ui.Theme.previewColorScheme = previousScheme;
        width = 1200;
    }
    function acknowledge(bar, call): void {
        Io.DaemonSessions.sessions[bar.controller.backend.daemonName].client.response(call.id,
            {protocol: BarApi.protocol, version: BarApi.version, ok: true, data: {}}, "", call.route);
    }
    function fixture(): var {
        const bar = createTemporaryObject(factory, testCase);
        verify(bar !== null);
        wait(0);
        for (const call of calls) acknowledge(bar, call);
        calls = [];
        verify(waitForPolish(bar.Window.window));
        return bar;
    }
    function click(item): void { mouseClick(item, item.width / 2, item.height / 2); }

    function test_categoryIdentityAndAcknowledgedWorkspaceAction(): void {
        const bar = fixture();
        const glyphs = ["terminal", "language", "code", "music_note", "description"];
        const names = ["Shell", "Browser", "Code", "Media", "Text"];
        for (let i = 0; i < 5; ++i) {
            const button = findChild(bar, "barWorkspace:" + (i + 1));
            compare(button.width, 32);
            compare(findChild(button, "workspaceCategoryGlyph").symbol, glyphs[i]);
            verify(button.Accessible.name.includes(names[i]));
            verify(!button.activeFocusOnTab);
        }
        const shell = findChild(bar, "barWorkspace:1");
        const mediaWorkspace = findChild(bar, "barWorkspace:4");
        const text = findChild(bar, "barWorkspace:5");
        verify(shell.active);
        verify(!mediaWorkspace.occupied);
        verify(findChild(text, "workspaceUrgency").visible);
        click(mediaWorkspace);
        compare(calls.length, 1);
        compare(calls[0].method, BarApi.methods.workspaceFocus);
        compare(calls[0].params.workspace_id, 4);
        verify(calls[0].params.on_current_monitor);
        verify(shell.active && !mediaWorkspace.active, "request admission does not invent compositor acknowledgement");
        compare(bar.registry.opened.length, 0, "the Media category is not the media-panel opener");
        acknowledge(bar, calls[0]);
        bar.controller.workspaces = Object.assign({}, bar.controller.workspaces, {
            monitors: [{name: "test", active_workspace_id: 4}],
            active_window: {class_name: "a.different.app", initial_class: "another.icon"}
        });
        verify(mediaWorkspace.active && !shell.active);
        compare(findChild(mediaWorkspace, "workspaceCategoryGlyph").symbol, "music_note", "focused app never replaces category identity");
        compare(mediaWorkspace.width, 32, "selection never expands or labels its target");
        mediaWorkspace.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(calls.length, 2, "shared action-control keyboard route survives");
        compare(calls[1].params.workspace_id, 4);
    }
    function test_chromaticStates_data(): var {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_chromaticStates(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const bar = fixture();
        const shell = findChild(bar, "barWorkspace:1");
        const tile = findChild(shell, "workspaceTile");
        const glyph = findChild(shell, "workspaceCategoryGlyph");
        compare(tile.color, Qt.color("transparent"));
        compare(findChild(shell, "workspaceOccupancy"), null, "no lower marker remains");
        compare(glyph.color, Ui.Theme.accent);
        compare(glyph.font.pixelSize, 22);
        compare(glyph.font.weight, Ui.Theme.fontWeightDemiBold);
        verify(shell.Accessible.checked);
        const occupiedGlyph = findChild(findChild(bar, "barWorkspace:3"), "workspaceCategoryGlyph");
        const emptyGlyph = findChild(findChild(bar, "barWorkspace:4"), "workspaceCategoryGlyph");
        compare(occupiedGlyph.color, Ui.Theme.text);
        compare(occupiedGlyph.font.pixelSize, 20);
        compare(occupiedGlyph.font.weight, Ui.Theme.fontWeightDemiBold);
        compare(emptyGlyph.color, Ui.Theme.mutedText);
        compare(emptyGlyph.font.pixelSize, 20);
        compare(emptyGlyph.font.weight, Ui.Theme.fontWeightRegular);
        for (const color of [glyph.color, occupiedGlyph.color, emptyGlyph.color])
            verify(Contrast.ratio(color, Ui.Theme.surface) >= 3, "workspace foreground remains legible");
        verify(waitForRendering(tile));
        const occupiedPixels = grabImage(tile);
        bar.controller.workspaces = Object.assign({}, bar.controller.workspaces, {
            workspaces: [{id: 1, monitor: "test", windows: 0, urgent: true}]
        });
        compare(glyph.color, Ui.Theme.accent, "empty and urgent do not erase selection");
        compare(glyph.font.pixelSize, 22);
        compare(glyph.font.weight, Ui.Theme.fontWeightRegular);
        verify(shell.enabled && shell.Accessible.checked);
        compare(tile.border.color, Ui.Theme.danger);
        compare(tile.border.width, 1);
        verify(findChild(shell, "workspaceUrgency").visible);
        // Compare only the central glyph region, excluding urgency decoration.
        verify(waitForRendering(tile));
        const emptyPixels = grabImage(tile);
        let changed = 0;
        for (let y = 7; y < 27; ++y)
            for (let x = 6; x < 26; ++x)
                if (String(occupiedPixels.pixel(x, y)) !== String(emptyPixels.pixel(x, y))) ++changed;
        verify(changed > 0, "occupancy changes actual glyph rendering, not just its colour");
        compare(calls.length, 0, "presentation changes never dispatch commands");
    }
    function test_layoutSectioningAndOverflow(): void {
        const bar = fixture();
        for (const size of [3440, 1200, 760, 600, 300]) {
            testCase.width = size;
            bar.width = size;
            verify(waitForPolish(bar.Window.window));
            const workspaces = findChild(bar, "barWorkspaces");
            const media = findChild(bar, "barMedia");
            const status = findChild(bar, "barStatusGroup");
            verify(media.x >= workspaces.x + workspaces.width + bar.groupGap);
            verify(media.x + media.width + bar.groupGap <= status.x);
            if (size >= 1200)
                compare(media.mapToItem(bar, media.width / 2, 0).x, size / 2, "media remains screen-centred");
            for (const name of ["network", "bluetooth", "notifications"])
                compare(findChild(bar, "bar:" + name).iconSize, 20);
            compare(findChild(bar, "barTrayButton").iconSize, 20);
            for (const name of ["battery", "notifications"]) {
                const section = findChild(bar, "barSection:" + name);
                const rule = section.children[0];
                verify(section.visible);
                compare(rule.height, 18);
                compare(rule.x + bar.statusItemGap, bar.statusSectionGap);
                compare(section.width - rule.x - rule.width, bar.statusSectionGap);
            }
            const tray = findChild(bar, "barTray");
            const clock = findChild(bar, "barClockAction");
            compare(clock.x - tray.x - tray.width, bar.clockGroupGap);
            compare(findChild(clock, "barClock").font.pixelSize, 14);
            compare(findChild(clock, "barClock").font.weight, Ui.Theme.fontWeightDemiBold);
            compare(findChild(clock, "barClockDate").visible, bar.layoutDensity < 2);
            compare(findChild(bar, "barOverflowButton").visible, bar.overflow);
            if (size === 300) {
                verify(bar.overflow);
                const viewport = findChild(bar, "barOverflowViewport");
                click(findChild(bar, "barOverflowButton"));
                verify(viewport.contentX > 0, "overflow reveals the unchanged full control strip");
            }
        }
        compare(calls.length, 0, "layout and scrolling never activate modules");
        bar.width = testCase.width = 1200;
        verify(waitForPolish(bar.Window.window));
        click(findChild(bar, "barClockAction"));
        compare(bar.registry.timeTab, "time");
    }
    function test_workspaceRevealAndMonitorLocalSelection(): void {
        const bar = fixture();
        bar.width = 300;
        bar.controller.workspaces = {
            monitors: [{name: "test", active_workspace_id: 12}, {name: "other", active_workspace_id: 2}],
            focused_monitor: "other", workspaces: [
                {id: 1, monitor: "test", windows: 1, urgent: true},
                {id: 12, monitor: "test", windows: 1}, {id: 2, monitor: "other", windows: 1}]
        };
        verify(waitForPolish(bar.Window.window));
        const selected = findChild(bar, "barWorkspace:12");
        verify(selected.active && selected.Accessible.checked);
        compare(findChild(selected, "workspaceCategoryGlyph").glyph, "12");
        verify(!findChild(bar, "barWorkspace:2").active, "selection is local to this output, not the focused monitor");
        const viewport = findChild(bar, "workspaceViewport");
        tryVerify(() => viewport.contentX > 0);
        const point = selected.mapToItem(viewport, 0, 0);
        verify(point.x >= 0 && point.x + selected.width <= viewport.width);
        verify(findChild(bar, "workspaceUrgencyAggregate").visible, "offscreen urgency is retained");
        compare(calls.length, 0);
    }
    function test_batteryReadingAndExternalMark_data(): var {
        return [
            {tag: "empty", state: {available: true, percentage: 0, critical: true}, fraction: 0, mark: "priority_high", word: "Critical"},
            {tag: "one-percent", state: {available: true, percentage: 1}, fraction: .01, mark: "", word: "1%"},
            {tag: "low", state: {available: true, percentage: 10, warning: true}, fraction: .1, mark: "priority_high", word: "Low battery"},
            {tag: "half", state: {available: true, percentage: 50}, fraction: .5, mark: "", word: "50%"},
            {tag: "charging", state: {available: true, percentage: 80, charging: true, plugged: true}, fraction: .8, mark: "bolt", word: "Charging"},
            {tag: "holding", state: {available: true, percentage: 80, plugged: true}, fraction: .8, mark: "power", word: "not charging"},
            {tag: "full", state: {available: true, percentage: 100, plugged: true}, fraction: 1, mark: "check", word: "Fully charged"},
            {tag: "null-reading", state: {available: true, percentage: null}, fraction: 0, mark: "help_outline", word: "unavailable"},
        ];
    }
    function test_batteryReadingAndExternalMark(data): void {
        const bar = fixture();
        bar.controller.battery = data.state;
        const button = findChild(bar, "bar:battery");
        const gauge = findChild(button, "barBatteryGauge");
        const body = findChild(gauge, "barBatteryBody");
        const mark = findChild(gauge, "barBatteryStateMark");
        const fill = findChild(gauge, "barBatteryFill");
        const interior = findChild(gauge, "barBatteryInterior");
        compare(gauge.fraction, data.fraction);
        compare(gauge.width, 36);
        compare(gauge.height, 26);
        compare(body.width, 18);
        compare(body.height, 26);
        compare(mark.width, 14);
        compare(gauge.x + gauge.width / 2, gauge.parent.width / 2);
        verify(mark.x + mark.width <= gauge.width);
        verify(interior.x > 0 && interior.x + interior.width < body.width);
        verify(interior.y > 0 && interior.y + interior.height < body.height);
        tryCompare(fill, "height", interior.height * data.fraction);
        compare(fill.color, data.state.critical ? Ui.Theme.danger : data.state.warning ? Ui.Theme.warning : Ui.Theme.accent);
        compare(gauge.stateMark, data.mark);
        compare(mark.symbol, data.mark);
        verify(mark.x >= body.x + body.width + 4, "state mark has a real gap outside the battery body");
        verify(mark.clip, "fallback fonts cannot paint back over the gauge");
        compare(mark.visible, data.mark.length > 0);
        compare(fill.visible, data.mark !== "help_outline");
        verify(button.Accessible.name.includes(data.word));
        compare(button.width, 42, "empty state-mark slot remains reserved");
        if (mark.visible) click(mark);
        else click(body);
        compare(bar.registry.opened, ["battery"], "body and side mark share one existing panel route");
        button.Accessible.pressAction();
        compare(bar.registry.opened.length, 2);
        compare(calls.length, 0, "rendering and inspecting never change power policy");
    }
}
