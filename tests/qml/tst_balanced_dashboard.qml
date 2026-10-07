pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui
import Shelllist.Io as Io
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
    function cleanup(): void { Ui.Theme.previewColorScheme = previousScheme; }
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
    function itemX(item, relativeTo): real { return item.mapToItem(relativeTo, 0, 0).x; }

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
    function test_workspaceOverflowRevealsActiveAndRetainsUrgency(): void {
        const bar = fixture();
        const entries = [];
        for (let id = 1; id <= 20; ++id) entries.push({id, monitor: "test", windows: 1, urgent: id === 1});
        bar.controller.workspaces = {monitors: [{name: "test", active_workspace_id: 20}], workspaces: entries};
        const strip = findChild(bar, "barWorkspaces");
        const viewport = findChild(strip, "workspaceViewport");
        tryVerify(() => viewport.contentX > 0);
        const active = findChild(bar, "barWorkspace:20");
        verify(active !== null);
        compare(findChild(active, "workspaceCategoryGlyph").text, "20");
        verify(itemX(active, viewport) >= 0);
        verify(itemX(active, viewport) + active.width <= viewport.width + 1);
        verify(findChild(strip, "workspaceUrgencyAggregate").visible);
        compare(calls.length, 0, "restoring/revealing a workspace does not focus it");
    }
    function test_centeredCollisionFreeGroupsAndNarrowOverflow(): void {
        const bar = fixture();
        const workspaces = findChild(bar, "barWorkspaces");
        const media = findChild(bar, "barMedia");
        const status = findChild(bar, "barStatusGroup");
        const viewport = findChild(bar, "barOverflowViewport");
        for (const width of [3440, 1200, 760, 600, 300]) {
            bar.width = width;
            verify(waitForPolish(bar.Window.window));
            verify(itemX(workspaces, bar) + workspaces.width <= itemX(media, bar));
            verify(itemX(media, bar) + media.width <= itemX(status, bar));
            if (width >= 1200) compare(Math.round(itemX(media, bar) + media.width / 2), width / 2, "wide media is screen-centered");
            for (const name of ["mediaArtworkButton", "mediaRewindButton", "mediaPlayPauseButton", "mediaForwardButton"])
                verify(findChild(bar, name).visible, "no density hides " + name);
        }
        verify(bar.overflow);
        const opener = findChild(bar, "mediaArtworkButton");
        const overflow = findChild(bar, "barOverflowButton");
        click(overflow);
        verify(viewport.contentX > 0);
        // Reach the combined numeric clock using the real overflow control.
        const clock = findChild(bar, "barClockAction");
        for (let i = 0; i < 8 && itemX(clock, viewport) + clock.width > viewport.width; ++i) click(overflow);
        verify(itemX(clock, viewport) >= 0 && itemX(clock, viewport) + clock.width <= viewport.width + 1);
        click(clock);
        compare(bar.registry.opened, ["time-weather"]);
        compare(bar.registry.timeTab, "time");
        compare(calls.length, 0);
        click(overflow);
        compare(viewport.contentX, 0, "overflow returns to the start without changing destinations");
        click(opener);
        compare(bar.registry.opened, ["time-weather", "media"]);
        bar.width = 1200;
        verify(waitForPolish(bar.Window.window));
        tryCompare(viewport, "contentX", 0);
        verify(!bar.overflow);
    }
    function test_numericClockIsOneDirectTarget(): void {
        const bar = fixture();
        bar.now = new Date(2026, 9, 7, 10, 32);
        const clock = findChild(bar, "barClockAction");
        const time = findChild(clock, "barClock");
        const date = findChild(clock, "barClockDate");
        compare(time.text, "10:32");
        compare(date.text, "10-07");
        verify(clock.Accessible.name.includes("2026-10-07 10:32"));
        click(time);
        click(date);
        clock.Accessible.pressAction();
        compare(bar.registry.opened, ["time-weather", "time-weather", "time-weather"]);
        bar.width = 760;
        verify(waitForPolish(bar.Window.window));
        verify(!date.visible && time.visible);
        clock.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(bar.registry.opened.length, 4);
        compare(calls.length, 0);
    }
    function test_batteryReadingAndExternalMark_data(): var {
        return [
            {tag: "empty", state: {available: true, percentage: 0, critical: true}, fraction: 0, mark: "priority_high", word: "Critical"},
            {tag: "low", state: {available: true, percentage: 12, warning: true}, fraction: .12, mark: "priority_high", word: "Low battery"},
            {tag: "no-invented-threshold", state: {available: true, percentage: 12}, fraction: .12, mark: "", word: "On battery"},
            {tag: "charging", state: {available: true, percentage: 52, charging: true, plugged: true}, fraction: .52, mark: "bolt", word: "Charging"},
            {tag: "holding", state: {available: true, percentage: 80, plugged: true}, fraction: .8, mark: "power", word: "not charging"},
            {tag: "inhibited", state: {available: true, percentage: 80, plugged: true, state: "charging-inhibited"}, fraction: .8, mark: "power", word: "inhibited"},
            {tag: "full", state: {available: true, percentage: 100, state: "fully-charged"}, fraction: 1, mark: "check", word: "Fully charged"},
            {tag: "clamp", state: {available: true, percentage: 105}, fraction: 1, mark: "", word: "100%"},
            {tag: "unavailable", state: {available: false, percentage: 52}, fraction: 0, mark: "help_outline", word: "unavailable"},
            {tag: "missing-reading", state: {available: true}, fraction: 0, mark: "help_outline", word: "unavailable"},
            {tag: "null-reading", state: {available: true, percentage: null}, fraction: 0, mark: "help_outline", word: "unavailable"},
            {tag: "nan-reading", state: {available: true, percentage: NaN}, fraction: 0, mark: "help_outline", word: "unavailable"},
            {tag: "infinite-reading", state: {available: true, percentage: Infinity}, fraction: 0, mark: "help_outline", word: "unavailable"}
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
        tryCompare(fill, "height", interior.height * data.fraction);
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
    function test_batteryFillPaintAndSnapshotBinding(): void {
        const bar = fixture();
        const button = findChild(bar, "bar:battery");
        const interior = findChild(button, "barBatteryInterior");
        const fill = findChild(button, "barBatteryFill");
        for (const scheme of [Qt.Light, Qt.Dark]) {
            Ui.Theme.previewColorScheme = scheme;
            bar.controller.battery = {available: true, percentage: 50, charging: true, plugged: true};
            tryCompare(fill, "height", interior.height / 2);
            verify(waitForRendering(interior));
            const pixels = grabImage(testCase);
            const lower = interior.mapToItem(testCase, 5, 14);
            const upper = interior.mapToItem(testCase, 5, 1);
            compare(pixels.pixel(Math.floor(lower.x), Math.floor(lower.y)), Ui.Theme.accent, "stored charge fills from the bottom");
            verify(pixels.pixel(Math.floor(upper.x), Math.floor(upper.y)) !== Ui.Theme.accent, "unfilled half is not covered by a state symbol");
        }
        bar.controller.battery = {available: false};
        verify(!fill.visible);
        bar.controller.battery = {available: true, percentage: 1};
        tryCompare(fill, "height", interior.height / 100);
        bar.controller.battery = {available: true, percentage: 80, plugged: true};
        tryCompare(fill, "height", interior.height * .8);
        compare(findChild(button, "barBatteryStateMark").glyph, "power");
        compare(calls.length, 0);
    }
}
