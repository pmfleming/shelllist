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
        text: qsTr("Application actions")
    }

    Repeater {
        model: actions.desktopActions

        delegate: Ui.LabeledAction {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            uiScale: actions.uiScale
            label: modelData.name || "Application action"
            // Desktop icon names are opaque, not necessarily font ligatures.
            // The passive full action name disambiguates the execute fallback.
            icon: Ui.MaterialIcons.name(modelData.icon || "") || "play_arrow"
            enabled: !actions.controller.operationBlocked && !actions.controller.operations.busy(actions.application.id)
            onClicked: actions.controller.triggerDetailAction("desktop-action-" + index)
        }
    }
}
