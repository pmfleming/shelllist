pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayFocusModel.js" as Focus

Ui.DetailFlickable {
    id: page
    required property DisplayController controller
    objectName: "displayFocusPane"
    viewMemory: controller.viewMemory
    memoryTab: controller.detailsTab
    revealFocusedControl: true
    onContentHeightChanged: Qt.callLater(revealFocus)
    onHeightChanged: Qt.callLater(revealFocus)
    readonly property bool overview: controller.detailsTab === "focus"
    readonly property bool diagnostics: controller.detailsTab === "focus-diagnostics"
    readonly property list<string> commonKeys: ["input:follow_mouse", "misc:mouse_move_focuses_monitor", "input:mouse_refocus"]
    readonly property string focusedMonitor: controller.workspaceState.available ? controller.workspaceState.focused_monitor || "" : (controller.outputs.find(o => !!o.focused && !o.disabled) || {}).name || ""
    readonly property var activeWindow: controller.workspaceState.available ? controller.workspaceState.active_window : null
    readonly property string windowMonitor: activeWindow ? ((controller.workspaceState.workspaces || []).find(w => w.id === activeWindow.workspace_id) || {}).monitor || "" : ""

    Ui.ThemeText {
        objectName: "displayFocusStatus"
        width: parent.width
        text: page.controller.pendingAction === "focus" || page.controller.pendingAction === "focusReset" ? qsTr("Saving…") : page.controller.focusState.error || (!page.controller.focusState.available ? qsTr("Waiting for compositor capabilities") : page.controller.dirty || page.controller.trial ? qsTr("Finish or discard layout changes to edit focus settings.") : qsTr("All monitors · Enter or Tab saves; Escape discards"))
        wrapMode: Text.Wrap
        color: page.controller.focusState.error ? Ui.Theme.warning : Ui.Theme.mutedText
    }
    Ui.DetailColumnCard {
        objectName: "displayCommonFocus"
        visible: page.overview
        title: qsTr("Focus")
        Repeater {
            model: Focus.groups()[0].settings.filter(entry => page.commonKeys.includes(entry.key))
            delegate: DisplayFocusSetting {
                required property var modelData
                Layout.fillWidth: true
                controller: page.controller
                entry: modelData
            }
        }
    }
    Ui.DetailColumnCard {
        objectName: "displayAdvancedFocus"
        visible: page.overview
        title: qsTr("Advanced")
        contentSpacing: 0
        Repeater {
            model: Focus.groups()
            delegate: DisplaySettingsLink {
                required property var modelData
                objectName: "focusCategory-" + modelData.id
                accessKey: ({pointer: "P", keyboard: "K", applications: "A", cursor: "C"})[modelData.id] || ""
                Layout.fillWidth: true
                title: modelData.title
                subtitle: modelData.summary
                icon: modelData.icon
                onClicked: page.controller.selectFocusPage("focus-" + modelData.id)
            }
        }
    }
    Repeater {
        model: Focus.groups()
        delegate: Ui.DetailColumnCard {
            id: groupCard
            required property var modelData
            visible: page.controller.detailsTab === "focus-" + modelData.id
            title: modelData.title
            Repeater {
                model: groupCard.modelData.settings.filter(entry => !page.commonKeys.includes(entry.key))
                delegate: DisplayFocusSetting {
                    required property var modelData
                    Layout.fillWidth: true
                    controller: page.controller
                    entry: modelData
                }
            }
        }
    }
    DisplaySettingsLink {
        objectName: "focusDiagnosticsLink"
        accessKey: "D"
        width: parent.width
        visible: page.overview
        title: qsTr("Diagnostics")
        icon: "info"
        onClicked: page.controller.selectFocusPage("focus-diagnostics")
    }
    Ui.DetailSection {
        informationOnly: true
        objectName: "displayFocusTechnical"
        visible: page.diagnostics
        title: qsTr("Diagnostics")
        Ui.ThemeText {
            objectName: "displayFocusedMonitor"
            Layout.fillWidth: true
            text: qsTr("Active monitor: %1").arg(page.focusedMonitor || qsTr("Not reported"))
            wrapMode: Text.Wrap
        }
        Ui.ThemeText {
            objectName: "displayFocusedWindow"
            Layout.fillWidth: true
            text: page.activeWindow ? qsTr("Focused window: ") + (page.activeWindow.title || page.activeWindow.class_name || qsTr("Untitled")) + (page.windowMonitor ? qsTr(" · Monitor: ") + page.windowMonitor : "") : qsTr("Focused window: not reported")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
        }
        Repeater {
            model: Focus.groups().reduce((entries, group) => entries.concat(group.settings), [])
            delegate: Ui.ThemeText {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.key + ": " + ((page.controller.focusState.values || {})[modelData.key] === undefined ? qsTr("Unavailable") : String(page.controller.focusState.values[modelData.key])) + ((page.controller.focusState.saved || {})[modelData.key] !== undefined ? qsTr(" · Saved override") : "")
                wrapMode: Text.Wrap
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }
    Ui.DetailSection {
        objectName: "displayFocusRestore"
        visible: page.diagnostics && Object.keys(page.controller.focusState.saved || {}).length > 0
        title: qsTr("Restore previous settings")
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Removes Shelllist overrides and restores values from before their first edit. Later reloads follow your Hyprland configuration.")
            wrapMode: Text.Wrap
        }
        Ui.LabeledAction {
            icon: "restore"
            objectName: "resetDisplayFocus"
            accessKey: "X"
            Layout.fillWidth: true
            label: qsTr("Restore previous settings")
            enabled: page.controller.canSetFocus && Object.keys(page.controller.focusState.saved || {}).length > 0
            onClicked: page.controller.resetFocusSettings()
        }
    }
}
