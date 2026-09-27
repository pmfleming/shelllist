import QtQuick

// Logical coordinates only. Placement reserves expansion space, but the host's
// visual/input region contains only the currently painted content.
QtObject {
    property real availableWidth: 1280
    property real availableHeight: 960
    property bool expandable: true

    readonly property int edgeMargin: Math.max(0, Math.min(compact ? Theme.spacingSm : Theme.contentMargin, Math.floor((availableWidth - 1) / 2), Math.floor((availableHeight - 1) / 2)))
    readonly property bool compact: availableWidth < 1200 || availableHeight < 800
    readonly property int contentMargin: compact ? Theme.spacingSm : Theme.contentMargin
    readonly property int detailsGap: compact ? Theme.spacingSm : Theme.detailsGapWidth
    readonly property int minimumContentHeight: 360
    readonly property int closedWidth: Theme.popupClosedWidth
    // Below this canvas size, scroll rather than shrinking controls or replacing
    // the list with details. 960 leaves at least 495px for the inspector.
    readonly property int openWidth: expandable ? Math.max(960, Math.min(Theme.popupOpenWidth, availableWidth - 2 * edgeMargin)) : closedWidth
    readonly property int surfaceWidth: Math.max(1, Math.min(openWidth, availableWidth - 2 * edgeMargin))
    readonly property int height: Math.max(1, Math.min(availableHeight - 2 * edgeMargin, Math.max(minimumContentHeight, Math.min(900, Math.round(availableHeight * Theme.popupHeightRatio)))))
    readonly property int x: Math.max(edgeMargin, Math.min(Math.round((availableWidth - closedWidth) / 2), Math.floor(availableWidth - edgeMargin - surfaceWidth)))
    readonly property int y: Math.max(edgeMargin, Math.round((availableHeight - height) / 2))
}
