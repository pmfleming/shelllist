import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    required property NotificationController controller
    readonly property var policy: controller.appPolicy
    readonly property bool settingsAvailable: controller.notificationState.nativeAvailable && !controller.appBusy
    viewMemory: controller.viewMemory
    memoryTab: "controls"
    function save(changes: var): void { controller.notificationState.setAppPolicy(controller.selectedAppKey, changes); }
    NotificationAppHeader { width: parent.width; controller: page.controller }
    Ui.ThemeText {
        width: parent.width
        text: qsTr("Silenced apps still add notifications to the list.")
        color: Ui.Theme.mutedText
        wrapMode: Text.WordWrap
    }
    Ui.FormField {
        width: parent.width; label: qsTr("Popups"); icon: "notifications"
        Ui.DropDownList {
            objectName: "notificationAppDelivery"
            Layout.fillWidth: true
            Accessible.name: qsTr("Application popup delivery")
            value: page.policy.silent ? "silent" : "normal"
            interactive: page.settingsAvailable
            options: [{value: "normal", label: qsTr("Allow popups")}, {value: "silent", label: qsTr("Silent: list only")}]
            onSelected: function (value) { page.save({silent: value === "silent", until_unix_ms: null}); }
        }
    }
    Ui.FormField {
        width: parent.width; label: qsTr("Quiet period"); icon: "schedule"
        visible: page.policy.silent
        Ui.DropDownList {
            objectName: "notificationAppDuration"
            Layout.fillWidth: true
            Accessible.name: qsTr("Application quiet period")
            value: page.policy.until_unix_ms ? "current" : "0"
            interactive: page.settingsAvailable
            options: (page.policy.until_unix_ms ? [{value: "current", label: qsTr("Until %1").arg(new Date(page.policy.until_unix_ms).toLocaleTimeString())}] : []).concat([
                {value: "30", label: qsTr("30 minutes")}, {value: "60", label: qsTr("1 hour")}, {value: "0", label: qsTr("Until changed")}
            ])
            onSelected: function (value) { if (value !== "current") page.save({until_unix_ms: Number(value) ? Date.now() + Number(value) * 60000 : null}); }
        }
    }
    Ui.ToggleRow {
        objectName: "notificationAppGrouping"
        width: parent.width; title: qsTr("Group similar notifications")
        checked: page.policy.group_similar
        interactive: page.settingsAvailable
        onClicked: page.save({group_similar: !checked})
    }
    Ui.ToggleRow {
        objectName: "notificationAppBypass"
        width: parent.width; title: qsTr("Bypass Do Not Disturb")
        checked: page.policy.bypass_dnd
        interactive: page.settingsAvailable
        onClicked: page.save({bypass_dnd: !checked})
    }
    Ui.ThemeText {
        width: parent.width
        text: page.controller.notificationState.policyErrors[page.controller.selectedAppKey] || (page.controller.appBusy ? qsTr("Saving…") : "")
        visible: text.length > 0
        color: page.controller.appBusy ? Ui.Theme.mutedText : Ui.Theme.danger
        wrapMode: Text.WordWrap
    }
    Ui.LabeledAction {
        width: parent.width
        icon: "refresh"; label: qsTr("Reset app defaults"); accessKey: "E"
        uiScale: Ui.Theme.expandedSecondaryActionScale
        enabled: page.settingsAvailable
        onClicked: page.save({silent: false, until_unix_ms: null, group_similar: true, bypass_dnd: false})
    }
}
