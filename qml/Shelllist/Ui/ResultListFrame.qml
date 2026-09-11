import QtQuick

Rectangle {
    id: frame

    required property Component rowDelegate
    required property ChooserController controller
    property var resultModel: null
    property int selectedIndex: 0
    property real uiScale: 1
    property string emptyText: ""
    property string emptyIcon: ""
    property bool emptyVisible: list.count === 0
    readonly property int count: list.count
    readonly property bool listFocused: list.activeFocus
    readonly property real delegateHeight: Theme.listDelegateHeight(height)

    signal keyPressed(var event)

    function focusList() {
        list.forceActiveFocus();
    }
    function revealSelection() {
        // ListView tracks the old delegate through inserts/moves/removals, even
        // when the controller's index has not changed. Reconcile from the
        // logical selection after model changes, never from that delegate.
        const index = frame.selectedIndex >= 0 && frame.selectedIndex < list.count ? frame.selectedIndex : -1;
        list.currentIndex = index;
        if (index >= 0)
            list.positionViewAtIndex(index, ListView.Contain);
    }
    onSelectedIndexChanged: revealSelection()
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
        objectName: "resultListView"

        anchors.fill: parent
        clip: true
        model: frame.resultModel
        // Reconcile after a mutation batch; a binding alone does not undo
        // ListView's internal index changes when selectedIndex stays the same.
        onCountChanged: Qt.callLater(frame.revealSelection)
        activeFocusOnTab: true
        Keys.onPressed: function (event) {
            frame.keyPressed(event);
        }
        onCurrentIndexChanged: Qt.callLater(frame.revealSelection)
        delegate: frame.rowDelegate
    }

    Connections {
        target: frame.controller
        function onUiActiveChanged() {
            if (frame.controller.uiActive)
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

        Behavior on opacity {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
            }
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

        Behavior on opacity {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
            }
        }
    }

    CenteredMessage {
        objectName: "resultListEmptyMessage"
        anchors.fill: parent
        z: 3
        visible: frame.emptyVisible
        text: frame.emptyIcon || frame.emptyText
        font.family: frame.emptyIcon ? Theme.iconFontFamily : Theme.fontFamily
        font.pixelSize: frame.emptyIcon ? Math.round(64 * frame.uiScale) : Math.max(Theme.fontSizeCaption, Math.round(Theme.fontSizeBody * frame.uiScale))
        Accessible.role: Accessible.StaticText
        Accessible.name: frame.emptyText
    }
}
