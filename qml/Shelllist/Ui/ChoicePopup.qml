import QtQuick
import QtQuick.Controls as Controls

// Shared option-list composition for ordinary and searchable choices.
Controls.Popup {
    id: popup
    required property Item owner
    property int optionCount: 0
    property alias model: list.model
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex
    signal keyPressed(var event)

    closePolicy: Controls.Popup.CloseOnPressOutside
    margins: Theme.spacingSm
    // The searchable editor keeps focus while browsing, so suggestions must not
    // cover it. Recompute the anchor whenever a reused modal shows this popup.
    readonly property real anchorY: visible && owner.Window.window
        ? owner.mapToItem(owner.Window.window.contentItem, 0, 0).y : 0
    readonly property real spaceAbove: Math.max(0, anchorY - Theme.spacingXs - margins)
    readonly property real spaceBelow: Math.max(0, (owner.Window.window ? owner.Window.window.height : 0)
        - anchorY - owner.height - Theme.spacingXs - margins)
    readonly property real desiredHeight: Math.min(optionCount, 6) * Theme.formCompactHeight + topPadding + bottomPadding
    y: desiredHeight <= spaceBelow || spaceBelow >= spaceAbove ? owner.height + Theme.spacingXs : -height - Theme.spacingXs
    width: owner.width
    padding: Theme.spacingSm
    height: Math.min(desiredHeight, Math.max(spaceAbove, spaceBelow))

    contentItem: ScrollableListView {
        id: list
        Keys.onPressed: function(event) { popup.keyPressed(event); }
        clip: true
        implicitHeight: contentHeight
        boundsBehavior: Flickable.StopAtBounds
        function revealCurrent(): void {
            if (currentIndex >= 0 && currentIndex < count)
                positionViewAtIndex(currentIndex, ListView.Contain);
        }
        onCurrentIndexChanged: Qt.callLater(revealCurrent)
        onCountChanged: Qt.callLater(revealCurrent)
    }
    background: Rectangle {
        radius: 12
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border
    }
    // Keyboard highlighting must never wait for a fade.
    enter: null
    exit: null
}
