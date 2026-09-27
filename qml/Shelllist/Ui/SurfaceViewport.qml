import QtQuick
import QtQuick.Controls as Controls

// Emergency overflow for work areas smaller than the supported split canvas.
// Native controls and inner list/detail flickables retain their own gestures.
Flickable {
    id: viewport

    property real canvasWidth: width
    property real canvasHeight: height
    readonly property Item focusedItem: Window.window ? Window.window.activeFocusItem : null
    contentWidth: Math.max(width, canvasWidth)
    contentHeight: Math.max(height, canvasHeight)
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    acceptedButtons: Qt.NoButton
    interactive: contentWidth > width || contentHeight > height
    clip: true

    function revealItem(item: Item): void {
        if (!item || !item.visible)
            return;
        let ancestor = item.parent;
        while (ancestor && ancestor !== contentItem)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        const point = item.mapToItem(contentItem, 0, 0);
        contentX = Math.max(0, Math.min(contentWidth - width, Math.min(point.x - Theme.spacingSm, Math.max(contentX, point.x + item.width + Theme.spacingSm - width))));
        contentY = Math.max(0, Math.min(contentHeight - height, Math.min(point.y - Theme.spacingSm, Math.max(contentY, point.y + item.height + Theme.spacingSm - height))));
    }
    function revealFocus(): void {
        contentX = Math.max(0, Math.min(contentWidth - width, contentX));
        contentY = Math.max(0, Math.min(contentHeight - height, contentY));
        let target = focusedItem;
        let ancestor = target;
        while (ancestor && ancestor !== contentItem) {
            if (ancestor instanceof TextField || ancestor instanceof ChooserListPane)
                target = ancestor;
            ancestor = ancestor.parent;
        }
        revealItem(target);
    }
    onFocusedItemChanged: Qt.callLater(revealFocus)
    onWidthChanged: Qt.callLater(revealFocus)
    onHeightChanged: Qt.callLater(revealFocus)
    onContentWidthChanged: Qt.callLater(revealFocus)
    onContentHeightChanged: Qt.callLater(revealFocus)

    Controls.ScrollBar.horizontal: Controls.ScrollBar {
        height: 6
        padding: 0
        Accessible.name: qsTr("Horizontal surface scroll")
        policy: viewport.contentWidth > viewport.width ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
        background: null
        contentItem: Rectangle { radius: 3; color: Theme.mutedText }
    }
    Controls.ScrollBar.vertical: Controls.ScrollBar {
        width: 6
        padding: 0
        Accessible.name: qsTr("Vertical surface scroll")
        policy: viewport.contentHeight > viewport.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
        background: null
        contentItem: Rectangle { radius: 3; color: Theme.mutedText }
    }
}
