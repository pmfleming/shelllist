pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: actions

    required property ApplicationController controller
    required property var application
    required property real uiScale
    readonly property var desktopActions: application.desktop_actions || []

    Layout.fillWidth: true
    spacing: Math.round(Ui.Theme.spacingMd * uiScale)

    Ui.SectionLabel {
        visible: actions.desktopActions.length > 0
        text: "Application actions"
    }

    Repeater {
        model: actions.desktopActions

        delegate: Ui.ActionButton {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(42 * actions.uiScale)
            label: modelData.name || "Application action"
            icon: modelData.icon || ""
            enabled: !actions.controller.actionInFlight
            onClicked: actions.controller.triggerDetailAction("desktop-action-" + index)
        }
    }
}
