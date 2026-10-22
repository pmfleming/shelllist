pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Item {
    id: stack
    required property var group
    required property BarController controller
    property real maximumHeight: 480
    property bool readingGuarded: expanded
    readonly property bool expanded: hover.hovered || cards.activeFocus
    readonly property bool stacked: group.records.length > 1
    property real cardHeight: 0
    width: 390
    implicitHeight: Math.min(maximumHeight, expanded ? cards.contentHeight : cardHeight + (stacked ? 8 : 0))

    function measure(): void {
        let height = 0;
        for (let i = 0; i < repeater.count; ++i)
            height = Math.max(height, repeater.itemAt(i)?.implicitHeight || 0);
        // Shrinking a dismissed tallest card must not move the remaining close
        // targets while reading. Collapse releases this presentation-only floor.
        cardHeight = expanded ? Math.max(cardHeight, height) : height;
    }
    onExpandedChanged: if (!expanded) Qt.callLater(measure)
    HoverHandler { id: hover }
    Flickable {
        id: cards
        objectName: "notificationDeckCards"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: stack.expanded ? repeater.count * (stack.cardHeight + Ui.Theme.spacingSm) - Ui.Theme.spacingSm : stack.cardHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        interactive: stack.expanded && contentHeight > height
        onInteractiveChanged: if (!interactive) contentY = 0
        Repeater {
            id: repeater
            model: Core.SerializedListModel {
                rows: (stack.group.records || []).map(record => ({key: Ui.NotificationPresentation.recordKey(record), payload: record}))
            }
            onItemAdded: Qt.callLater(stack.measure)
            onItemRemoved: Qt.callLater(stack.measure)
            NotificationToastCard {
                required property var resultData
                required property int index
                objectName: "notificationDeckCard" + notification.id
                notification: JSON.parse(resultData.payload)
                controller: stack.controller
                width: cards.width
                height: stack.cardHeight
                y: index * (stack.expanded ? stack.cardHeight + Ui.Theme.spacingSm : 4)
                z: repeater.count - index
                visible: stack.expanded || index < 3
                enabled: stack.expanded || index === 0
                pauseCountdown: stack.readingGuarded
                groupCount: stack.expanded ? 1 : stack.group.records.length
                breakoutVisible: stack.stacked && !stack.expanded
                onBreakoutRequested: stack.controller.openNotificationCenter(stack.group.key)
                onImplicitHeightChanged: Qt.callLater(stack.measure)
                Ui.InteractiveBehavior on y { duration: Ui.Theme.animationNormal }
            }
        }
    }
}
