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
        text: "Set the workspace used when a new window is launched. Existing windows are not moved."
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }

    Ui.DetailColumnCard {
        height: 150
        title: "Default workspace"
        contentSpacing: Ui.Theme.spacingMd

        Ui.DropDownList {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: Preferences.workspaceOptions()
            value: page.application.default_workspace_id || ""
            interactive: !page.controller.settingsInFlight
            onSelected: function (value) {
                page.controller.updateApplicationSettings(page.application.category || "shell", value);
            }
        }

        Text {
            Layout.fillWidth: true
            text: page.application.default_workspace_id
                ? "New windows default to workspace " + page.application.default_workspace_id + "."
                : "New windows open on the workspace where the launcher was invoked."
            color: Ui.Theme.subtleText
            wrapMode: Text.Wrap
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
}
