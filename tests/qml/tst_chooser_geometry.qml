pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Shelllist.Ui as Ui

DaemonTestCase {
    id: testCase
    name: "ChooserGeometry"
    when: windowShown
    visible: true
    width: 1100
    height: 900

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
                        objectName: "geometrySurface"
                        chooserController: controller
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
            compare(surface.listItem.mapToItem(fixture, 0, 0).x, left,
                "progress=" + fixture.controller.detailsExpansionProgress
                + " canvas=" + fixture.controller.currentWindowWidth
                + " listLoader.x=" + surface.listItem.parent.x
                + " viewport.contentX=" + fixture.visual.children[0].contentX);
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
        compare(editor.height, Ui.Theme.formHeight, "tight margins do not shrink controls");
        verify(surface.detailsItem.width >= 495);
        tryVerify(() => surface.detailsItem.mapToItem(surface, surface.detailsItem.width, 0).x <= surface.width);
        fixture.controller.detailsOpen = false;
        tryCompare(fixture.visual, "width", fixture.controller.closedWindowWidth);
        compare(fixture.visual.x, 0);
        compare(fixture.height, frameHeight);
        compare(fixture.edits, 0);
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
        keyClick(Qt.Key_Tab);
        tryVerify(() => viewport.contentX > 0);
        verify(surface.listItem.visible && surface.detailsItem.visible);
        keyClick(Qt.Key_Return);
        verify(surface.detailsNavigation.editing);
        const editor = findChild(surface, "geometryEditor");
        tryCompare(fixture.controller, "detailsExpansionProgress", 1);
        tryVerify(() => editor.mapToItem(viewport, 0, 0).x >= 0 && editor.mapToItem(viewport, editor.width, 0).x <= viewport.width + 1);
        keyClick(Qt.Key_Escape);
        keyClick(Qt.Key_Down);
        verify(surface.listItem.listFocused);
        verify(fixture.controller.detailsOpen);
        keyClick(Qt.Key_Tab);
        compare(surface.detailsNavigation.currentTarget.objectName, "geometryEditor");
        verify(surface.detailsNavigation.browsing);
        keyClick(Qt.Key_Escape);
        verify(surface.listItem.listFocused);
        keyClick(Qt.Key_Up);
        keyClick(Qt.Key_Up);
        tryVerify(() => surface.listItem.searchFocused);
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
