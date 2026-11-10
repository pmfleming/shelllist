pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: card
    required property DisplayController controller
    readonly property var draft: controller.selectedDraft || ({})
    readonly property var relative: draft.relative || null
    title: qsTr("Placement and identity")
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Match display by")
        Ui.DropDownList {
            objectName: "displayIdentityMatch"
            Layout.fillWidth: true
            interactive: card.controller.canEdit
            options: [{value: "identity", label: qsTr("Monitor identity")}, {value: "connector", label: qsTr("Connector") }]
            value: card.draft.match_connector ? "connector" : "identity"
            onSelected: value => card.controller.edit(card.controller.selectedName, "match_connector", value === "connector")
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Position")
        Ui.DropDownList {
            objectName: "displayPositionMode"
            Layout.fillWidth: true
            interactive: card.controller.canArrange
            options: [{value: "absolute", label: qsTr("Absolute")}, {value: "relative", label: qsTr("Relative to display")}]
            value: card.relative ? "relative" : "absolute"
            onSelected: value => card.controller.setRelative(card.controller.selectedName, value === "relative" ? {} : null)
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        visible: !!card.relative
        label: qsTr("Reference display")
        Ui.DropDownList {
            objectName: "displayRelativeReference"
            Layout.fillWidth: true
            interactive: card.controller.canArrange
            options: card.controller.placementReferences.map(o => ({value: o.name, label: o.name}))
            value: card.relative ? card.relative.reference : ""
            onSelected: value => card.controller.setRelative(card.controller.selectedName, {reference: value})
        }
    }
    Repeater {
        model: [
            {key: "side", label: qsTr("Side"), values: ["left", "right", "above", "below"], labels: [qsTr("Left"), qsTr("Right"), qsTr("Above"), qsTr("Below")]},
            {key: "alignment", label: qsTr("Alignment"), values: ["start", "center", "end"], labels: [qsTr("Start"), qsTr("Center"), qsTr("End")]}
        ]
        delegate: Ui.FormField {
            id: choiceRow
            required property var modelData
            Layout.fillWidth: true
            visible: !!card.relative
            label: modelData.label
            Ui.DropDownList {
                objectName: "displayRelative-" + choiceRow.modelData.key
                Layout.fillWidth: true
                readonly property var entry: choiceRow.modelData
                interactive: card.controller.canArrange
                options: entry.values.map((v, i) => ({value: v, label: entry.labels[i]}))
                value: card.relative ? card.relative[entry.key] : ""
                onSelected: value => card.controller.setRelative(card.controller.selectedName, {[entry.key]: value})
            }
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        visible: !!card.relative
        label: qsTr("Gap")
        Ui.TextField {
            objectName: "displayRelativeGap"
            Layout.fillWidth: true
            enabled: card.controller.canArrange
            text: String(card.relative ? card.relative.gap : 0)
            suffix: qsTr("px")
            inputValid: /^\d+$/.test(text) && Number(text) <= 4096
            onEdited: value => { if (/^\d+$/.test(value) && Number(value) <= 4096) card.controller.setRelative(card.controller.selectedName, {gap: Number(value)}); }
        }
    }
}
