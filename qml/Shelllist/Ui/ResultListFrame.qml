import QtQuick

Rectangle {
    id: frame

    required property Component rowDelegate
    required property ChooserController controller
    property var resultModel: null
    property int selectedIndex: 0
    property real uiScale: 1
    property string emptyText: ""
    property bool emptyVisible: list.count === 0
    readonly property int count: list.count
    readonly property bool listFocused: list.activeFocus
    readonly property real delegateHeight: Theme.listDelegateHeight(height)

    signal keyPressed(var event)

    function focusList() { list.forceActiveFocus(); }
    function focusTop() {
        controller.selectFirst();
        focusList();
        list.positionViewAtBeginning();
    }
    function pick(rowIndex) {
        controller.select(rowIndex);
        focusList();
    }
    function toggleDetails(rowIndex) {
        controller.select(rowIndex);
        controller.toggleDetails();
        focusList();
    }

    radius: Theme.panelRadius
    color: Theme.surface
    border.color: Theme.border
    clip: true

    ScrollableListView {
        id: list

        anchors.fill: parent
        clip: true
        model: frame.resultModel
        // A large catalog is appended over several event-loop turns. Keep the
        // logical selection without asking ListView for an index it does not
        // have yet; this binding reactivates as soon as that chunk arrives.
        currentIndex: frame.selectedIndex < count ? frame.selectedIndex : -1
        activeFocusOnTab: true
        Keys.onPressed: function (event) {
            frame.keyPressed(event);
        }
        onCurrentIndexChanged: if (currentIndex >= 0 && count > 0)
            positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: frame.rowDelegate
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.min(28, Math.max(16, frame.delegateHeight * 0.48))
        z: 2
        opacity: list.count > 0 && !list.atYBeginning ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Theme.surface }
            GradientStop { position: 1; color: Theme.withAlpha(Theme.surface, 0) }
        }

        Behavior on opacity {
            enabled: !Theme.noAnimations
            NumberAnimation { duration: Theme.animationFast }
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
            GradientStop { position: 0; color: Theme.withAlpha(Theme.surface, 0) }
            GradientStop { position: 1; color: Theme.surface }
        }

        Behavior on opacity {
            enabled: !Theme.noAnimations
            NumberAnimation { duration: Theme.animationFast }
        }
    }

    CenteredMessage {
        z: 3
        visible: frame.emptyVisible
        text: frame.emptyText
        font.pixelSize: Math.max(Theme.fontSizeCaption, Math.round(Theme.fontSizeBody * frame.uiScale))
    }
}
