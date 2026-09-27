pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity
import "../../qml/Shelllist/Io/HyprlandWorkArea.js" as WorkArea

DaemonTestCase {
    id: testCase
    name: "ChooserGeometry"
    when: windowShown
    visible: true
    width: 1100
    height: 900

    Component {
        id: geometryFactory
        Ui.PopoverGeometry {}
    }
    Component {
        id: fixtureFactory
        Item {
            id: fixture
            property real areaWidth: 1280
            property real areaHeight: 720
            property alias controller: controller
            property alias visual: visual
            property int edits: 0
            width: controller.geometry.surfaceWidth
            height: controller.geometry.height

            Ui.ChooserController {
                id: controller
                availableScreenWidth: fixture.areaWidth
                availableScreenHeight: fixture.areaHeight
                uiActive: true
                hasSelection: true
                function primarySelected() { fixture.edits++; return true; }
                selectionModel: QtObject {
                    property string queryText: ""
                    property int selectedIndex: 0
                    function selectFirst() { selectedIndex = 0; }
                    function move(delta) { selectedIndex = Math.max(0, Math.min(2, selectedIndex + delta)); }
                }
            }
            Ui.VisualSurface {
                id: visual
                contentWidth: Math.min(controller.currentWindowWidth, controller.geometry.surfaceWidth)
                canvasWidth: controller.currentWindowWidth
                minimumContentHeight: controller.geometry.minimumContentHeight
                loadWhen: true
                content: Component {
                    Ui.ProviderChooserSurface {
                        id: surface
                        objectName: "geometrySurface"
                        chooserController: controller
                        keyboardWorkflow: true
                        listComponent: Component {
                            Ui.ChooserListPane {
                                id: pane
                                chooserController: controller
                                resultModel: controller.selectionModel.queryText.length > 0 ? [] : ["First", "Second", "Third"]
                                filterText: controller.selectionModel.queryText
                                powerVisible: false
                                rowDelegate: Component {
                                    Ui.ResultRow {
                                        objectName: "geometryResult"
                                        listPane: pane
                                        Ui.ResultLabel {
                                            objectName: "geometryResultLabel"
                                            title: "Result"
                                        }
                                    }
                                }
                            }
                        }
                        detailsComponent: Component {
                            Ui.DetailFlickable {
                                Ui.TextField {
                                    objectName: "geometryEditor"
                                    width: parent.width
                                    text: "Ordinary text"
                                    onEdited: fixture.edits++
                                }
                                Ui.ThemeText {
                                    width: parent.width
                                    height: 900
                                    text: "Long read-only information"
                                }
                                Ui.ActionButton {
                                    objectName: "geometryAction"
                                    width: parent.width
                                    label: "Action"
                                    onClicked: fixture.edits++
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: activityFactory
        Item {
            id: activity
            property alias controller: controller
            width: controller.currentWindowWidth
            height: controller.geometry.height
            Activity.ActivityController {
                id: controller
                availableScreenWidth: 1280
                availableScreenHeight: 720
            }
            Activity.ActivityContent { controller: activity.controller }
        }
    }
    function test_activityExpandsRightOfItsGlanceRail() {
        const activity = createTemporaryObject(activityFactory, testCase);
        const glance = findChild(activity, "activityGlancePane");
        verify(glance !== null);
        const left = glance.mapToItem(activity, 0, 0).x;
        const width = glance.width;
        const height = glance.height;
        activity.controller.openSection("schedule");
        for (let frame = 0; frame < 12; ++frame) {
            wait(20);
            compare(glance.mapToItem(activity, 0, 0).x, left);
            compare(glance.width, width);
            compare(glance.height, height);
        }
        verify(activity.controller.detailsOpen);
        activity.controller.closeSection();
        tryCompare(activity, "width", activity.controller.closedWindowWidth);
        compare(glance.mapToItem(activity, 0, 0).x, left);
    }
    function init() {
        failOnWarning(/.*/);
        Quickshell.environment = {SHELLLIST_NO_ANIMATIONS: "false"};
    }
    function cleanup() {
        Quickshell.environment = ({});
    }
    function surfaceFor(fixture) {
        const surface = findChild(fixture, "geometrySurface");
        verify(surface !== null);
        return surface;
    }
    function test_bounds_data() {
        return [
            {tag: "minimum-supported", width: 976, height: 600},
            {tag: "logical-hidpi-laptop", width: 1024, height: 640},
            {tag: "laptop", width: 1280, height: 720},
            {tag: "desktop", width: 1920, height: 1080},
            {tag: "ultrawide", width: 3440, height: 1440},
            {tag: "overflow", width: 800, height: 500},
            {tag: "tiny-emergency", width: 400, height: 240}
        ];
    }
    function test_bounds(data) {
        const geometry = createTemporaryObject(geometryFactory, testCase, {availableWidth: data.width, availableHeight: data.height});
        verify(geometry.x >= geometry.edgeMargin);
        verify(geometry.y >= geometry.edgeMargin);
        verify(geometry.x + geometry.surfaceWidth <= data.width - geometry.edgeMargin);
        verify(geometry.y + geometry.height <= data.height - geometry.edgeMargin);
        compare(geometry.closedWidth, Ui.Theme.popupClosedWidth);
        verify(geometry.openWidth >= 960);
        verify(geometry.openWidth <= Ui.Theme.popupOpenWidth);
        verify(geometry.height <= 900);
        // The list is as close to centered as possible without moving on expansion.
        compare(geometry.x, Math.max(geometry.edgeMargin, Math.min(Math.round((data.width - geometry.closedWidth) / 2), data.width - geometry.edgeMargin - geometry.surfaceWidth)));
    }
    function test_workAreaAndSingleColumn() {
        const area = WorkArea.rectangle({x: -1920, y: -100, width: 1920, height: 1080}, {left: 26, top: 82, right: 12, bottom: 22});
        const geometry = createTemporaryObject(geometryFactory, testCase, {availableWidth: area.width, availableHeight: area.height});
        const desktopX = area.x + geometry.x;
        const desktopY = area.y + geometry.y;
        verify(desktopX >= -1920 + 26);
        verify(desktopX + geometry.surfaceWidth <= -12);
        verify(desktopY >= -100 + 82);
        verify(desktopY + geometry.height <= -100 + 1080 - 22);
        geometry.expandable = false;
        compare(geometry.openWidth, geometry.closedWidth);
        compare(geometry.x, Math.round((area.width - geometry.closedWidth) / 2));
        // Reconnect fallback uses the screen rectangle, not stale reserved space.
        const fallback = WorkArea.rectangle({x: 0, y: 0, width: 1024, height: 640}, null);
        geometry.availableWidth = fallback.width;
        geometry.availableHeight = fallback.height;
        verify(geometry.x + geometry.surfaceWidth <= fallback.width);
    }
    function test_expansionFilteringAndResizeKeepListAnchored() {
        const fixture = createTemporaryObject(fixtureFactory, testCase);
        const surface = surfaceFor(fixture);
        surface.listItem.focusList();
        const left = surface.listItem.mapToItem(fixture, 0, 0).x;
        const top = surface.listItem.y;
        const listHeight = surface.listItem.height;
        const frameHeight = fixture.height;
        const anchor = fixture.controller.geometry.x;
        compare(fixture.visual.width, fixture.controller.closedWindowWidth);
        compare(fixture.visual.x, 0);
        verify(fixture.width > fixture.visual.width, "reserved area is outside the visual/input region");
        keyClick(Qt.Key_Right);
        for (let frame = 0; frame < 12; ++frame) {
            wait(20);
            compare(surface.listItem.mapToItem(fixture, 0, 0).x, left);
            compare(surface.listItem.y, top);
            compare(surface.listItem.height, listHeight);
            compare(fixture.controller.geometry.x, anchor);
        }
        tryVerify(() => surface.detailsItem !== null);
        verify(surface.listItem.visible && surface.detailsItem.visible);
        compare(fixture.visual.width, fixture.controller.openWindowWidth);
        fixture.controller.selectionModel.queryText = "no matches";
        wait(0);
        compare(fixture.height, frameHeight);
        compare(surface.listItem.height, listHeight);
        fixture.areaWidth = 1024;
        wait(0);
        verify(surface.listItem.visible && surface.detailsItem.visible);
        const editor = findChild(surface, "geometryEditor");
        compare(editor.height, Ui.Theme.controlHeight, "tight margins do not shrink controls");
        verify(surface.detailsItem.width >= 495);
        tryVerify(() => surface.detailsItem.mapToItem(surface, surface.detailsItem.width, 0).x <= surface.width);
        fixture.controller.detailsOpen = false;
        tryCompare(fixture.visual, "width", fixture.controller.closedWindowWidth);
        compare(fixture.visual.x, 0);
        compare(fixture.height, frameHeight);
        compare(fixture.edits, 0);
    }
    function test_focusedDelegateUsesSharedQueryGuardsAndDetailFocus() {
        const fixture = createTemporaryObject(fixtureFactory, testCase);
        const surface = surfaceFor(fixture);
        tryVerify(() => findChild(surface, "geometryResult") !== null);
        findChild(surface, "geometryResult").forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(fixture.controller.selectionModel.queryText, " ");
        verify(surface.listItem.searchFocused, "a focused delegate cannot swallow printable query text");
        fixture.controller.selectionModel.queryText = "";
        verify(waitForPolish(fixture.Window.window));
        tryVerify(() => findChild(surface, "geometryResult") !== null);
        findChild(surface, "geometryResult").forceActiveFocus();
        fixture.controller.navigationBlocked = true;
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(fixture.edits, 0);
        verify(!fixture.controller.detailsOpen);
        fixture.controller.navigationBlocked = false;
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsNavigation.browsing);
        verify(fixture.controller.detailsOpen);
    }
    function test_textAndControlsDoNotScaleWithWorkArea() {
        const fixture = createTemporaryObject(fixtureFactory, testCase, {areaWidth: 976, areaHeight: 600});
        const surface = surfaceFor(fixture);
        const search = findChild(surface.listItem, "fieldInput");
        verify(search !== null);
        for (const height of [600, 1080, 720]) {
            fixture.areaHeight = height;
            verify(waitForPolish(fixture.Window.window));
            compare(search.parent.height, Ui.Theme.controlHeight);
            compare(search.font.pixelSize, Ui.Theme.fontSizeLabel);
            compare(surface.listItem.delegateHeight, Ui.Theme.listRowHeight);
            compare(findChild(surface, "geometryResult").height, Ui.Theme.listRowHeight);
            compare(findChild(surface, "geometryResultLabel").titlePixelSize, Ui.Theme.fontSizeLabel);
            compare(surface.uiScale, 1);
        }
    }
    function test_overflowRevealsKeyboardTargetsWithoutReplacingList() {
        const fixture = createTemporaryObject(fixtureFactory, testCase, {areaWidth: 800, areaHeight: 500});
        const surface = surfaceFor(fixture);
        const viewport = fixture.visual.children[0];
        verify(viewport instanceof Ui.SurfaceViewport);
        surface.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => surface.detailsItem !== null && surface.detailsNavigation.currentTarget !== null);
        tryVerify(() => viewport.contentWidth > viewport.width);
        tryVerify(() => viewport.contentX > 0);
        verify(surface.listItem.visible && surface.detailsItem.visible);
        keyClick(Qt.Key_Right);
        verify(surface.detailsNavigation.editing);
        const editor = findChild(surface, "geometryEditor");
        tryCompare(fixture.controller, "detailsExpansionProgress", 1);
        tryVerify(() => editor.mapToItem(viewport, 0, 0).x >= 0 && editor.mapToItem(viewport, editor.width, 0).x <= viewport.width + 1);
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Down);
        compare(surface.detailsNavigation.currentTarget.objectName, "geometryAction");
        keyClick(Qt.Key_Tab);
        verify(surface.listItem.searchFocused);
        tryCompare(viewport, "contentX", 0);
        compare(fixture.edits, 0, "revealing focus never activates a setting/action");
        fixture.controller.detailsOpen = false;
        tryCompare(viewport, "contentWidth", fixture.controller.closedWindowWidth);
        compare(viewport.contentX, 0);
        // Short work areas expose native vertical scrolling instead of clipping chrome.
        fixture.areaHeight = 240;
        tryVerify(() => viewport.contentHeight > viewport.height);
        compare(viewport.contentHeight, fixture.controller.geometry.minimumContentHeight);
    }
}
