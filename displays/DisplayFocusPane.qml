pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayFocusModel.js" as Focus

Ui.DetailFlickable {
    id: page
    required property DisplayController controller
    objectName: "displayFocusPane"
    revealFocusedControl: true
    // Nested delegates and narrow layouts can change geometry after focus moves.
    onContentHeightChanged: Qt.callLater(revealFocus)
    onHeightChanged: Qt.callLater(revealFocus)
    readonly property string focusedMonitor: controller.workspaceState.available ? controller.workspaceState.focused_monitor || "" : (controller.outputs.find(o => !!o.focused && !o.disabled) || {}).name || ""
    readonly property var activeWindow: controller.workspaceState.available ? controller.workspaceState.active_window : null
    readonly property string windowMonitor: activeWindow ? ((controller.workspaceState.workspaces || []).find(w => w.id === activeWindow.workspace_id) || {}).monitor || "" : ""

    Ui.DetailColumnCard {
        objectName: "displayFocusScope"
        height: implicitHeight
        title: qsTr("Focus behaviour · all monitors")
        contentSpacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            objectName: "displayFocusedMonitor"
            Layout.fillWidth: true
            text: page.focusedMonitor ? qsTr("Currently active monitor: ") + page.focusedMonitor : qsTr("Currently active monitor: not reported")
            wrapMode: Text.Wrap
            font.bold: true
        }
        Ui.ThemeText {
            objectName: "displayFocusedWindow"
            Layout.fillWidth: true
            text: page.activeWindow ? qsTr("Focused window: ") + (page.activeWindow.title || page.activeWindow.class_name || qsTr("Untitled")) + (page.windowMonitor ? qsTr(" · Monitor: ") + page.windowMonitor : "") : qsTr("Focused window: not reported")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("These settings are global, not specific to the selected display. Changes apply immediately and are saved after compositor confirmation. They survive restart and configuration reload; untouched settings stay under your Hyprland configuration.")
            wrapMode: Text.Wrap
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("The active monitor normally follows the keyboard-focused window. A last-window shortcut can jump to a window on another monitor. Directional-navigation limits do not restrict explicit last-window or monitor shortcuts; this page does not rewrite your keybindings or per-window rules.")
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
        Ui.ThemeText {
            objectName: "displayFocusStatus"
            Layout.fillWidth: true
            text: page.controller.pendingAction === "focus" || page.controller.pendingAction === "focusReset" ? qsTr("Saving focus settings…") : page.controller.focusState.error || (!page.controller.focusState.available ? qsTr("Focus settings are unavailable · waiting for compositor capabilities") : page.controller.dirty || page.controller.trial ? qsTr("Finish or discard layout changes before changing focus behaviour.") : qsTr("Saved automatically · no layout preview needed"))
            wrapMode: Text.Wrap
            color: page.controller.focusState.error ? Ui.Theme.warning : Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
        Ui.ActionButton {
            objectName: "resetDisplayFocus"
            Layout.fillWidth: true
            label: qsTr("Restore previous focus settings")
            enabled: page.controller.canSetFocus && Object.keys(page.controller.focusState.saved || {}).length > 0
            onClicked: page.controller.resetFocusSettings()
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Restore removes Shelllist's overrides and restores each setting's value from before its first edit. Later configuration reloads are controlled by your Hyprland configuration again.")
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
    Repeater {
        model: Focus.groups()
        delegate: Ui.DetailColumnCard {
            id: groupCard
            required property var modelData
            height: implicitHeight
            title: modelData.title
            contentSpacing: Ui.Theme.spacingMd
            Repeater {
                model: groupCard.modelData.settings
                delegate: DisplayFocusSetting {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    controller: page.controller
                    entry: modelData
                }
            }
        }
    }
}
