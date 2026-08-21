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
        text: "Choose the application's category. Categories map directly to the first five workspaces, so this also sets where new windows launch."
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }

    Ui.DetailColumnCard {
        height: 300
        title: "Category & default workspace"
        contentSpacing: Ui.Theme.spacingXs

        Repeater {
            model: Preferences.categories

            delegate: Ui.ToggleRow {
                required property var modelData

                Layout.fillWidth: true
                title: modelData.icon + "  " + modelData.label
                subtitle: "Workspace " + modelData.workspace + " · " + modelData.description
                checked: page.application.category === modelData.value
                    && page.application.default_workspace_id === modelData.workspace
                interactive: !page.controller.settingsInFlight && !checked
                onClicked: page.controller.updateApplicationSettings(modelData.value)
            }
        }
    }

    Text {
        width: parent.width
        text: page.application.default_workspace_id
            ? "New windows launch on workspace "
                + page.application.default_workspace_id + ". Existing windows are not moved."
            : "No default workspace is set yet. Select a category to configure one."
        color: Ui.Theme.subtleText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
