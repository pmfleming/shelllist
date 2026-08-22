pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Rectangle {
    id: panel

    required property var application
    required property var latestPoint
    required property real uiScale
    readonly property var badges: Resources.metadataBadges(application, latestPoint)

    width: parent ? parent.width : 0
    height: badgeFlow.height + Math.round(24 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.72)
    border.width: 0

    Flow {
        id: badgeFlow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(12 * panel.uiScale)
        spacing: Math.round(Ui.Theme.spacingSm * panel.uiScale)
        height: childrenRect.height

        Repeater {
            model: panel.badges
            delegate: ApplicationResourceBadge {
                required property var modelData
                text: modelData.text
                tone: modelData.tone
            }
        }
    }
}
