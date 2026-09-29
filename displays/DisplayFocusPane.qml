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
    memoryTab: "focus"
    revealFocusedControl: true
    onContentHeightChanged: Qt.callLater(revealFocus)
    onHeightChanged: Qt.callLater(revealFocus)
    readonly property var commonKeys: ["input:follow_mouse", "misc:mouse_move_focuses_monitor", "input:mouse_refocus"]
    readonly property string focusedMonitor: controller.workspaceState.available ? controller.workspaceState.focused_monitor || "" : (controller.outputs.find(o => !!o.focused && !o.disabled) || {}).name || ""
    readonly property var activeWindow: controller.workspaceState.available ? controller.workspaceState.active_window : null
    readonly property string windowMonitor: activeWindow ? ((controller.workspaceState.workspaces || []).find(w => w.id === activeWindow.workspace_id) || {}).monitor || "" : ""

    Ui.ThemeText {
        objectName: "displayFocusStatus"
        width: parent.width
        text: page.controller.pendingAction === "focus" || page.controller.pendingAction === "focusReset" ? qsTr("Saving…") : page.controller.focusState.error || (!page.controller.focusState.available ? qsTr("Waiting for compositor capabilities") : page.controller.dirty || page.controller.trial ? qsTr("Finish or discard layout changes before changing focus behaviour.") : qsTr("All monitors · saved automatically"))
        wrapMode: Text.Wrap
        color: page.controller.focusState.error ? Ui.Theme.warning : Ui.Theme.mutedText
    }
    Ui.DetailColumnCard {
        height: implicitHeight
        title: qsTr("Pointer and window focus")
        Repeater {
            model: Focus.groups()[0].settings.filter(entry => page.commonKeys.includes(entry.key))
            delegate: DisplayFocusSetting {
                required property var modelData
                Layout.fillWidth: true
                controller: page.controller
                entry: modelData
                showDetails: technical.open
            }
        }
    }
    Ui.DisclosureSection {
        objectName: "displayAdvancedFocus"
        title: qsTr("Advanced focus behaviour")
        Repeater {
            model: Focus.groups()
            delegate: Ui.DetailColumnCard {
                id: groupCard
                required property var modelData
                Layout.fillWidth: true
                title: modelData.title
                Repeater {
                    model: groupCard.modelData.settings.filter(entry => !page.commonKeys.includes(entry.key))
                    delegate: DisplayFocusSetting {
                        required property var modelData
                        Layout.fillWidth: true
                        controller: page.controller
                        entry: modelData
                        showDetails: technical.open
                    }
                }
            }
        }
    }
    Ui.DisclosureSection {
        id: technical
        objectName: "displayFocusTechnical"
        title: qsTr("Explanations & technical details")
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
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Changes persist after compositor confirmation. Unchanged settings remain under your Hyprland configuration. Directional limits do not restrict explicit monitor or last-window shortcuts.")
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
        }
    }
    Ui.DisclosureSection {
        objectName: "displayFocusRestore"
        title: qsTr("Restore previous focus settings")
        visible: Object.keys(page.controller.focusState.saved || {}).length > 0
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Removes Shelllist overrides and restores the values from before their first edit. Later reloads use your Hyprland configuration again.")
            wrapMode: Text.Wrap
        }
        Ui.ActionButton {
            objectName: "resetDisplayFocus"
            Layout.fillWidth: true
            label: qsTr("Restore")
            enabled: page.controller.canSetFocus && Object.keys(page.controller.focusState.saved || {}).length > 0
            onClicked: page.controller.resetFocusSettings()
        }
    }
}
