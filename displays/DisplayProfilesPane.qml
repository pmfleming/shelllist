pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    required property DisplayController controller
    readonly property var profile: controller.editingProfile
    readonly property bool editable: controller.canChange && !controller.dockingApplying && !controller.dirty
    viewMemory: controller.viewMemory
    memoryTab: "profiles"
    revealFocusedControl: true
    Ui.FeedbackSource { text: page.controller.displayPolicyState.profile_reason || "" }
    Ui.DetailColumnCard {
        title: qsTr("Display profiles")
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Automatic switching")
            Ui.DropDownList {
                objectName: "displayProfileAutomatic"
                Layout.fillWidth: true
                interactive: page.editable
                options: [{value: "off", label: qsTr("Off")}, {value: "on", label: qsTr("On")}]
                value: page.controller.profiles.automatic ? "on" : "off"
                onSelected: value => page.controller.profileRequest({operation: "automatic", enabled: value === "on"})
            }
        }
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Profile")
            Ui.DropDownList {
                objectName: "displayProfileSelection"
                Layout.fillWidth: true
                interactive: page.editable
                options: (page.controller.profiles.items || []).map(p => ({value: p.name, label: p.name}))
                value: page.controller.profileEditorName
                onSelected: value => { page.controller.profileEditorName = value; }
            }
        }
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Fallback")
            Ui.DropDownList {
                objectName: "displayProfileFallback"
                Layout.fillWidth: true
                interactive: page.editable
                options: [{value: "", label: qsTr("Keep current layout")}].concat((page.controller.profiles.items || []).map(p => ({value: p.name, label: p.name})))
                value: page.controller.profiles.fallback || ""
                onSelected: value => page.controller.profileRequest({operation: "fallback", name: value || null})
            }
        }
        Ui.LabeledAction {
            Layout.fillWidth: true
            objectName: "displayProfilePreview"
            label: qsTr("Preview selected profile")
            icon: "preview"
            accessKey: "P"
            enabled: page.editable && !!page.profile
            onClicked: page.controller.profileRequest({operation: "preview", name: page.profile.name})
        }
    }
    Ui.DetailColumnCard {
        title: qsTr("Profile conditions")
        visible: !!page.profile
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Name")
            Ui.TextField {
                objectName: "displayProfileName"
                Layout.fillWidth: true
                enabled: page.editable
                text: page.profile ? page.profile.name : ""
                maximumLength: 80
                onEdited: value => { if (page.controller.updateProfile(page.profile, {renamed: value})) page.controller.profileEditorName = value; }
            }
        }
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Priority")
            Ui.TextField {
                objectName: "displayProfilePriority"
                Layout.fillWidth: true
                enabled: page.editable
                text: String(page.profile ? page.profile.priority : 0)
                inputValid: /^-?\d+$/.test(text) && Number(text) >= -32768 && Number(text) <= 32767
                onEdited: value => { if (/^-?\d+$/.test(value) && Number(value) >= -32768 && Number(value) <= 32767) page.controller.updateProfile(page.profile, {priority: Number(value)}); }
            }
        }
        Repeater {
            model: [{key: "plugged", label: qsTr("Power"), yes: qsTr("AC power"), no: qsTr("Battery")}, {key: "lid_closed", label: qsTr("Lid"), yes: qsTr("Closed"), no: qsTr("Open")}]
            delegate: Ui.FormField {
                id: conditionRow
                required property var modelData
                Layout.fillWidth: true
                label: modelData.label
                Ui.DropDownList {
                    objectName: "displayProfile-" + conditionRow.modelData.key
                    Layout.fillWidth: true
                    interactive: page.editable
                    options: [{value: "any", label: qsTr("Any")}, {value: "yes", label: conditionRow.modelData.yes}, {value: "no", label: conditionRow.modelData.no}]
                    value: !page.profile || page.profile[conditionRow.modelData.key] === null ? "any" : page.profile[conditionRow.modelData.key] ? "yes" : "no"
                    onSelected: value => page.controller.updateProfile(page.profile, {[conditionRow.modelData.key]: value === "any" ? null : value === "yes"})
                }
            }
        }
        Ui.LabeledAction {
            Layout.fillWidth: true
            label: qsTr("Remove profile")
            icon: "delete"
            accessKey: "X"
            enabled: page.editable && !!page.profile
            onClicked: page.controller.profileRequest({operation: "remove", name: page.profile.name})
        }
    }
    Ui.DetailColumnCard {
        title: qsTr("Save current layout")
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("New profile name")
            Ui.TextField {
                objectName: "displayProfileNewName"
                Layout.fillWidth: true
                enabled: page.editable
                text: page.controller.newProfileName
                maximumLength: 80
                onEdited: value => { page.controller.newProfileName = value; }
            }
        }
        Ui.LabeledAction {
            Layout.fillWidth: true
            objectName: "displayProfileCapture"
            label: qsTr("Save current layout as profile")
            icon: "save"
            accessKey: "S"
            enabled: page.editable && page.controller.newProfileName.trim().length > 0
            onClicked: { if (page.controller.profileRequest({operation: "capture", name: page.controller.newProfileName.trim()})) page.controller.profileEditorName = page.controller.newProfileName.trim(); }
        }
    }
}
