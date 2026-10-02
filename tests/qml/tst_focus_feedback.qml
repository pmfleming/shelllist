pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtTest
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Bar as Bar

TestCase {
    id: testCase
    name: "FocusFeedback"
    when: windowShown
    visible: true
    width: 500
    height: 240

    Component {
        id: buttons
        Item {
            width: 480
            height: 200
            property alias first: first
            property alias second: second
            property alias field: field
            Ui.FlatIconButton {
                id: first
                width: 64
                height: 42
                icon: "x"
                accessibleName: "First"
                toolTip: "Must never appear"
            }
            Ui.ActionButton {
                id: second
                x: 100
                width: 160
                height: 42
                label: "Second"
            }
            Ui.TextField {
                id: field
                y: 70
                width: 200
                password: true
            }
        }
    }
    Component {
        id: rows
        Item {
            id: scene
            width: 240
            height: 160
            property int selectedIndex: 0
            property bool selectionFocused: true
            property alias first: first
            property alias second: second
            Ui.ChooserListPane {
                id: pane
                visible: false
                chooserController: Ui.ChooserController {}
                rowDelegate: Component {
                    Item {}
                }
            }
            Ui.ResultRow {
                id: first
                width: 240
                index: 0
                listPane: pane
                rowHeight: 48
                selectedIndex: scene.selectedIndex
                selectionFocused: scene.selectionFocused
                detailsActionVisible: false
            }
            Ui.ResultRow {
                id: second
                y: 56
                width: 240
                index: 1
                listPane: pane
                rowHeight: 48
                selectedIndex: scene.selectedIndex
                selectionFocused: scene.selectionFocused
                detailsActionVisible: false
            }
        }
    }

    Component {
        id: workspaceFactory
        Bar.WorkspaceButton {
            workspaceId: 1
            screenName: "test"
            controller: Bar.BarController { surfaceRegistry: null; backend.active: false }
        }
    }
    SignalSpy { id: pickedSpy; signalName: "picked" }

    function test_segmentedRowsKeepPointerActionsAndSelectionSeparate() {
        const scene = createTemporaryObject(rows, testCase);
        const first = scene.first;
        const second = scene.second;
        first.detailsActionVisible = true;
        second.detailsActionVisible = true;
        first.listPane.chooserController.detailActions = [{id: "connect", icon: "+", enabled: true}];
        const firstAvatar = findChild(first, "resultAvatar");
        const secondAvatar = findChild(second, "resultAvatar");
        compare(firstAvatar.width, 40);
        compare(secondAvatar.width, 40);
        tryCompare(firstAvatar, "radius", 20);
        tryCompare(secondAvatar, "radius", 12);
        verify(findChild(first, "resultDetailsAction").visible);
        verify(!findChild(second, "resultDetailsAction").visible);
        compare(findChild(first, "resultPrimaryCue"), null, "list rows do not show Enter indicators");
        pickedSpy.target = second;
        pickedSpy.clear();
        mouseClick(second, second.width - 5, second.height / 2);
        compare(pickedSpy.count, 1, "the unselected trailing area still selects the row");
        pickedSpy.target = null;
        scene.selectedIndex = 1;
        tryCompare(firstAvatar, "radius", 12);
        tryCompare(secondAvatar, "radius", 20);
        verify(!findChild(first, "resultDetailsAction").visible);
        verify(findChild(second, "resultDetailsAction").visible);
    }

    function test_pointerAndKeyboardShareTonalFocusWithoutAnOutline() {
        const scene = createTemporaryObject(buttons, testCase);
        mouseClick(scene.first, 20, 20);
        verify(scene.first.activeFocus);
        const fill = scene.first.color;
        const tint = ring(scene.first).color;
        compare(ring(scene.first).border.width, 0);
        verify(ring(scene.first).color.a > 0);
        scene.second.forceActiveFocus();
        mouseMove(scene, 400, 180);
        scene.first.forceActiveFocus(Qt.TabFocusReason);
        compare(scene.first.color, fill);
        compare(ring(scene.first).color, tint);
        scene.first.browseFocused = true;
        scene.second.forceActiveFocus();
        compare(scene.first.color, fill, "browse focus uses the same paint without entering the control");
        compare(ring(scene.first).color, tint);
        scene.first.browseFocused = false;
        verify(!ring(scene.first).visible);
    }
    function test_workspaceFocusFollowsTheDiscNotTheTallHitArea() {
        const button = createTemporaryObject(workspaceFactory, testCase);
        button.forceActiveFocus(Qt.TabFocusReason);
        const highlight = ring(button);
        compare(highlight.parent, findChild(button, "workspaceDisc"));
        compare(highlight.border.width, 0);
        compare(highlight.width, highlight.height);
        compare(highlight.radius, highlight.height / 2);
        verify(highlight.height < button.height);
    }

    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {
            SHELLLIST_NO_ANIMATIONS: "false"
        };
        verify(!Ui.Theme.noAnimations);
    }

    function cleanup() {
        Quickshell.environment = ({});
    }

    function ring(control) {
        const indicator = findChild(control, "focusRing");
        verify(indicator !== null);
        return indicator;
    }

    function test_flatButtonFocusCannotWaitForHoverAnimation() {
        const scene = createTemporaryObject(buttons, testCase);
        scene.second.forceActiveFocus();
        mouseMove(scene.second, 20, 20);
        mouseMove(scene.first, 20, 20);
        wait(20);
        scene.first.forceActiveFocus();
        verify(ring(scene.first).visible);
        compare(String(scene.first.color), String(scene.first.highlightedBackgroundColor), "focus foreground needs its matching background immediately");
        scene.first.interactive = false;
        verify(scene.first.activeFocus);
        compare(String(scene.first.color), String(scene.first.highlightedBackgroundColor));
    }

    function test_focusMovesImmediatelyAndSurvivesBusyState() {
        const scene = createTemporaryObject(buttons, testCase);
        verify(scene !== null);
        const first = ring(scene.first);
        const second = ring(scene.second);
        scene.first.forceActiveFocus();
        verify(first.visible);
        verify(!second.visible);
        scene.second.forceActiveFocus();
        // No wait: the ring cannot queue behind decorative animations.
        verify(!first.visible);
        verify(second.visible);
        scene.second.interactive = false;
        verify(scene.second.activeFocus);
        verify(second.visible);
        verify(second.x >= 0 && second.y >= 0);
        verify(second.x + second.width <= scene.second.width);
        verify(second.y + second.height <= scene.second.height);
        scene.field.focusInput(false);
        verify(!second.visible);
        verify(ring(scene.field).visible);
    }

    function test_selectionFocusAndHoverRemainDistinct() {
        const scene = createTemporaryObject(rows, testCase);
        verify(scene !== null);
        verify(ring(scene.first).visible);
        verify(!ring(scene.second).visible);
        const initialHeight = scene.first.height;
        scene.selectedIndex = 1;
        verify(!ring(scene.first).visible);
        verify(ring(scene.second).visible);
        compare(scene.first.height, initialHeight);
        scene.selectionFocused = false;
        verify(scene.second.selected, "selection survives focus moving elsewhere");
        verify(!ring(scene.second).visible);
        mouseMove(scene.first, 24, 24);
        compare(scene.selectedIndex, 1, "hover never selects another item");
        verify(!ring(scene.first).visible);
    }

    function test_hoverDoesNotCreateATooltipOrStealFocus() {
        const scene = createTemporaryObject(buttons, testCase);
        verify(scene !== null);
        scene.second.forceActiveFocus();
        mouseMove(scene.first, 20, 20);
        wait(600); // Longer than the removed tooltip delay.
        verify(!scene.first.Controls.ToolTip.visible);
        verify(scene.second.activeFocus);
        compare(scene.first.Accessible.name, "First");
    }
}
