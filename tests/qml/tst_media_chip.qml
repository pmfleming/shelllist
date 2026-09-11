pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Bar as Bar

TestCase {
    id: testCase
    name: "MediaChip"
    when: windowShown
    visible: true
    width: 420
    height: 60

    Component {
        id: panelComponent
        Item {
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property var chip

            Bar.BarController {
                id: controller
                surfaceRegistry: null
                backend.active: false
                property var actions: []

                function mediaOperation(operation: string): bool {
                    actions = actions.concat([operation]);
                    return true;
                }
                function cycleMediaPlayer(): bool {
                    return mediaOperation("cycle");
                }
                function seekMedia(offsetSeconds: int): bool {
                    actions = actions.concat([offsetSeconds]);
                    return true;
                }
            }
        }
    }

    function makePanel(canSeek) {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.media = {
            available: true,
            active_player: "spotify",
            players: [
                { id: "browser", identity: "Browser" },
                { id: "spotify", title: "Track", playback_status: "playing",
                    can_control: true, can_seek: canSeek }
            ]
        };
        const component = Qt.createComponent("../../qml/Shelllist/Bar/MediaChip.qml");
        compare(component.status, Component.Ready, component.errorString());
        panel.chip = createTemporaryObject(component, panel, {
            controller: panel.controller,
            layoutDensity: 0,
            width: 400,
            height: 37
        });
        verify(panel.chip !== null);
        verify(waitForRendering(panel));
        return panel;
    }

    function test_buttonsReceiveTheirOwnClicks() {
        const panel = makePanel(true);
        const cases = [
            ["mediaCycleButton", "cycle"],
            ["mediaRewindButton", -15],
            ["mediaPlayPauseButton", "play-pause"],
            ["mediaForwardButton", 30]
        ];
        for (const entry of cases) {
            panel.controller.actions = [];
            const button = findChild(panel, entry[0]);
            verify(button !== null);
            verify(button.enabled);
            mouseClick(button, button.width / 2, button.height / 2);
            compare(panel.controller.actions, [entry[1]]);
        }
        panel.controller.actions = [];
        mouseClick(panel.chip, 50, panel.chip.height / 2);
        compare(panel.controller.actions, ["play-pause"]);
    }

    function test_buttonsHaveAccessibleNamesWithoutTooltips() {
        const panel = makePanel(true);
        for (const name of ["mediaCycleButton", "mediaRewindButton", "mediaPlayPauseButton", "mediaForwardButton"]) {
            const button = findChild(panel, name);
            verify(button !== null);
            compare(button.toolTip, "");
            verify(button.accessibleName.length > 0);
        }
    }

    function test_unseekablePlayerDoesNotSeekOrTogglePlayback() {
        const panel = makePanel(false);
        for (const name of ["mediaRewindButton", "mediaForwardButton"]) {
            const button = findChild(panel, name);
            verify(button !== null);
            compare(button.enabled, false);
            mouseClick(button, button.width / 2, button.height / 2);
        }
        compare(panel.controller.actions.length, 0);
    }
}
