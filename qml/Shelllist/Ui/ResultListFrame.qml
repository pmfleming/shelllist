import QtQuick

Rectangle {
    id: frame

    required property Component rowDelegate
    required property ChooserController controller
    property var resultModel: null
    property Component footerComponent: null
    property bool preserveViewportOnAppend: false
    readonly property bool nearEnd: list.count > 0 && list.height > 0 && list.contentHeight - (list.contentY - list.originY + list.height) <= 4 * delegateHeight
    property int selectedIndex: 0
    property real uiScale: 1
    property string emptyText: ""
    property string emptyIcon: ""
    property string emptyState: "empty"
    property bool emptyShowLabel: true
    property bool emptyVisible: list.count === 0
    readonly property int count: list.count
    readonly property bool listFocused: list.activeFocus
    readonly property real delegateHeight: Theme.listRowHeight

    property var viewportBookmark: null
    property bool reconcilingResults: false

    signal keyPressed(var event)

    function viewportState(): var {
        const index = list.indexAt(1, list.contentY + 1);
        const item = list.itemAtIndex(index);
        return item ? {key: controller.resultKeyAt(index), offset: list.contentY - item.y} : null;
    }
    function restoreViewport(state: var): void {
        viewportBookmark = state && state.key ? state : null;
        Qt.callLater(revealSelection);
    }
    function applyViewport(): bool {
        if (!viewportBookmark)
            return false;
        const bookmark = viewportBookmark;
        const index = controller.resultIndexForKey(bookmark.key);
        if (index < 0) {
            viewportBookmark = null;
            return false;
        }
        if (index >= list.count)
            return true; // Wait for the keyed model's remaining chunks.
        list.positionViewAtIndex(index, ListView.Beginning);
        list.contentY = Math.max(list.originY, Math.min(list.originY + Math.max(0, list.contentHeight - list.height), list.contentY + (Number(bookmark.offset) || 0)));
        return true;
    }

    function focusList() {
        list.forceActiveFocus();
    }
    function revealSelection() {
        if (reconcilingResults)
            return;
        // ListView tracks the old delegate through inserts/moves/removals, even
        // when the controller's index has not changed. Reconcile from the
        // logical selection after model changes, never from that delegate.
        const index = frame.selectedIndex >= 0 && frame.selectedIndex < list.count ? frame.selectedIndex : -1;
        list.currentIndex = index;
        if (!applyViewport() && index >= 0)
            list.positionViewAtIndex(index, ListView.Contain);
    }
    onSelectedIndexChanged: if (!reconcilingResults) {
        viewportBookmark = null;
        revealSelection();
    }
    function focusTop() {
        viewportBookmark = null;
        controller.selectFirst();
        focusList();
        list.positionViewAtBeginning();
    }
    function pick(rowIndex) {
        viewportBookmark = null;
        controller.select(rowIndex);
        focusList();
    }
    function toggleDetails(rowIndex) {
        viewportBookmark = null;
        controller.select(rowIndex);
        controller.toggleDetails();
        focusList();
    }

    radius: Theme.panelRadius
    color: "transparent"
    border.width: 0
    clip: true

    ScrollableListView {
        id: list
        objectName: "resultListView"

        anchors.fill: parent
        clip: true
        model: frame.resultModel
        spacing: 2
        // Reconcile after a mutation batch; a binding alone does not undo
        // ListView's internal index changes when selectedIndex stays the same.
        property int previousCount: 0
        onCountChanged: {
            // Paging must not pull a mouse-scrolled viewport back to selection.
            if (!frame.preserveViewportOnAppend || count <= previousCount)
                Qt.callLater(frame.revealSelection);
            previousCount = count;
        }
        footer: frame.footerComponent
        activeFocusOnTab: true
        onMovementStarted: {
            frame.viewportBookmark = null;
            frame.controller.navigationInteracted();
        }
        Keys.onPressed: function (event) {
            frame.keyPressed(event);
        }
        onCurrentIndexChanged: Qt.callLater(frame.revealSelection)
        delegate: frame.rowDelegate
    }

    Connections {
        target: frame.controller
        function onResultsAboutToChange(preserveViewport: bool): void {
            frame.reconcilingResults = true;
            frame.viewportBookmark = preserveViewport && frame.preserveViewportOnAppend ? frame.viewportState() : null;
        }
        function onResultsChanged(): void {
            frame.reconcilingResults = false;
            Qt.callLater(frame.revealSelection);
        }
        function onUiActiveChanged() {
            if (frame.controller.uiActive && !frame.controller.viewMemory)
                Qt.callLater(frame.revealSelection);
        }
    }

    Component.onCompleted: if (controller.uiActive)
        Qt.callLater(revealSelection)

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.min(28, Math.max(16, frame.delegateHeight * 0.48))
        z: 2
        opacity: list.count > 0 && !list.atYBeginning ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: Theme.surface
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(Theme.surface, 0)
            }
        }

        InteractiveBehavior on opacity {
            duration: Theme.animationFast
            easingType: Easing.Linear
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.min(28, Math.max(16, frame.delegateHeight * 0.48))
        z: 2
        opacity: list.count > 0 && !list.atYEnd ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: Theme.withAlpha(Theme.surface, 0)
            }
            GradientStop {
                position: 1
                color: Theme.surface
            }
        }

        InteractiveBehavior on opacity {
            duration: Theme.animationFast
            easingType: Easing.Linear
        }
    }

    ContentState {
        objectName: "resultListEmptyMessage"
        anchors.fill: parent
        z: 3
        visible: frame.emptyVisible
        active: frame.controller.uiActive
        text: frame.emptyText
        icon: frame.emptyIcon
        kind: frame.emptyState
        showLabel: frame.emptyShowLabel
        uiScale: frame.uiScale
    }
}
