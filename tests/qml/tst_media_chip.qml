pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui
import Shelllist.Io as Io
import "../../bar/BarApi.js" as BarApi

DaemonTestCase {
    id: testCase
    name: "MediaChip"
    when: windowShown
    visible: true
    width: 1200
    height: 80
    property int previousScheme
    readonly property string cover: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="white"/></svg>')

    Component {
        id: barFactory
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
                function surfaceRequested(name: string): void { opened = opened.concat([name]); }
            }
            controller: Bar.BarController { surfaceRegistry: bar.registry }
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
    function player(overrides): var {
        return Object.assign({id: "player", identity: "Player", title: "Current track", art_url: cover,
            playback_status: "Playing", can_control: true, can_pause: true, can_play: true,
            can_seek: true, can_previous: true, can_next: true, control_mode: "tracks"}, overrides || {});
    }
    function setPlayer(bar, value): void {
        bar.controller.media = {available: !!value, active_player: value ? value.id : "", players: value ? [value] : []};
    }
    function fixture(): var {
        const bar = createTemporaryObject(barFactory, testCase);
        verify(bar !== null);
        wait(0);
        for (const call of calls) acknowledge(bar, call);
        calls = [];
        setPlayer(bar, player({}));
        tryCompare(findChild(bar, "mediaArtwork"), "status", Image.Ready);
        verify(waitForPolish(bar.Window.window));
        return bar;
    }
    function click(item): void { mouseClick(item, item.width / 2, item.height / 2); }

    function test_openerAndTransportHaveSeparateRoutes_data(): var {
        return [{tag: "compact-seek", mode: "seek", width: 600}];
    }
    function test_openerAndTransportHaveSeparateRoutes(data): void {
        const bar = fixture();
        setPlayer(bar, player({control_mode: data.mode}));
        bar.width = data.width;
        verify(waitForPolish(bar.Window.window));
        const opener = findChild(bar, "mediaArtworkButton");
        compare(opener.Accessible.name, "Open Media. Current track");
        click(opener);
        compare(bar.registry.opened, ["media"]);
        compare(calls.length, 0, "opening Media cannot play, seek or pin");
        opener.Accessible.pressAction();
        compare(bar.registry.opened, ["media", "media"]);
        compare(calls.length, 0);
        bar.registry.opened = [];
        const names = ["mediaRewindButton", "mediaPlayPauseButton", "mediaForwardButton"];
        const operations = data.mode === "tracks" ? ["previous", "play-pause", "next"] : ["seek", "play-pause", "seek"];
        for (let i = 0; i < names.length; ++i) {
            click(findChild(bar, names[i]));
            compare(calls.length, i + 1);
            compare(calls[i].method, BarApi.methods.mediaOperation);
            compare(calls[i].params.operation, operations[i]);
            compare(calls[i].params.player_id, "player");
            if (operations[i] === "seek") compare(calls[i].params.offset_seconds, i === 0 ? -30 : 30);
            compare(bar.registry.opened.length, 0, "transport never opens the media panel");
            compare(bar.controller.activePlayer.playback_status, "Playing", "requests do not invent acknowledgements");
            acknowledge(bar, calls[i]);
        }
        setPlayer(bar, player({control_mode: data.mode, can_control: false}));
        for (const name of names) {
            const button = findChild(bar, name);
            verify(!button.enabled);
            click(button);
            button.Accessible.pressAction();
        }
        compare(calls.length, 3, "disabled transport cannot dispatch through either route");
        click(opener);
        compare(bar.registry.opened, ["media"], "panel access does not require transport capability");
    }
    function test_fallbackAndPlayerRemovalKeepDirectControls(): void {
        const bar = fixture();
        const chip = findChild(bar, "barMedia");
        const opener = findChild(chip, "mediaArtworkButton");
        const image = findChild(chip, "mediaArtwork");
        const backdrop = findChild(chip, "mediaArtworkBackdrop");
        const transport = findChild(chip, "mediaTransportControls");
        const expandedWidth = chip.implicitWidth;
        setPlayer(bar, player({art_url: ""}));
        tryCompare(image, "status", Image.Null);
        verify(!backdrop.visible && opener.icon.length > 0);
        compare(chip.implicitWidth, expandedWidth, "missing artwork does not shift transport");
        click(opener);
        ignoreWarning(/.*QML (?:QQuick)?Image: Cannot open: .*missing-media-cover\.png/);
        setPlayer(bar, player({art_url: Qt.resolvedUrl("fixtures/missing-media-cover.png").toString()}));
        tryCompare(image, "status", Image.Error);
        verify(!backdrop.visible && opener.icon.length > 0);
        click(opener);
        bar.width = 600;
        compare(bar.layoutDensity, 3);
        verify(transport.visible, "compact density keeps transport directly available");
        compare(chip.implicitWidth, expandedWidth);
        verify(waitForRendering(opener));
        click(opener);
        setPlayer(bar, null);
        tryCompare(image, "status", Image.Null);
        compare(opener.Accessible.name, "Open Media");
        compare(chip.implicitWidth, expandedWidth, "player removal keeps the control geometry");
        for (const name of ["mediaRewindButton", "mediaPlayPauseButton", "mediaForwardButton"]) {
            const button = findChild(chip, name);
            verify(button.visible && !button.enabled);
            click(button);
            button.Accessible.pressAction();
        }
        click(opener);
        compare(bar.registry.opened, ["media", "media", "media", "media"]);
        compare(calls.length, 0, "fallback and density changes never invoke transport");
        bar.width = 1200;
        setPlayer(bar, player({}));
        tryCompare(image, "status", Image.Ready);
        tryCompare(transport, "visible", true);
        compare(chip.implicitWidth, expandedWidth);
    }
    function test_artworkReallyClipsRoundedCorners(): void {
        const bar = fixture();
        if (bar.GraphicsInfo.api === GraphicsInfo.Software)
            skip("Qt Quick effects require an RHI renderer; run this pixel check with QT_QUICK_BACKEND=rhi");
        Ui.Theme.previewColorScheme = Qt.Dark;
        // Artwork geometry stays unchanged even in the narrow layout.
        bar.width = 600;
        const backdrop = findChild(bar, "mediaArtworkBackdrop");
        verify(waitForPolish(bar.Window.window));
        bar.Window.window.requestUpdate();
        verify(waitForRendering(backdrop));
        const pixels = grabImage(testCase);
        const origin = backdrop.mapToItem(testCase, 0, 0);
        const x = Math.round(origin.x), y = Math.round(origin.y);
        compare(pixels.pixel(x + 12, y + 12), Qt.color("white"), "image is still visible at its center");
        for (const corner of [[0, 0], [23, 0], [0, 23], [23, 23]])
            compare(pixels.pixel(x + corner[0], y + corner[1]), Ui.Theme.surfaceContainer, "bright cover corners are masked, not just the backing");
        compare(calls.length, 0);
    }
}
