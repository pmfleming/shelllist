pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application

    Text {
        width: parent.width
        text: "Choose where this application appears in the launcher categories."
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }

    Ui.DetailColumnCard {
        height: 270
        title: "App category"
        contentSpacing: Ui.Theme.spacingXs

        Repeater {
            model: Preferences.categories

            delegate: Ui.ToggleRow {
                required property var modelData

                Layout.fillWidth: true
                title: modelData.icon + "  " + modelData.label
                subtitle: modelData.description
                checked: page.application.category === modelData.value
                interactive: !page.controller.settingsInFlight
                onClicked: page.controller.updateApplicationSettings(
                    modelData.value, page.application.default_workspace_id || "")
            }
        }
    }
}
