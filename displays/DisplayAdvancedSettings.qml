pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: card
    required property DisplayController controller
    readonly property var output: controller.selectedOutput || ({})
    readonly property var draft: (controller.selectedDraft || {}).advanced || ({})
    readonly property var observed: output.advanced_observed || ({})
    readonly property var choices: output.advanced_options || ({})
    readonly property bool editable: controller.canEdit && !!(controller.selectedDraft || {}).enabled
    readonly property string colorPreset: draft.color || observed.color || ""
    title: qsTr("Advanced display")

    function label(key: string, value: var): string {
        if (value === undefined) return qsTr("Unavailable");
        if (key === "vrr") return value ? qsTr("On") : qsTr("Off");
        if (key === "bit_depth") return value === 10 ? qsTr("10-bit · test with Preview") : qsTr("8-bit");
        const colors = {srgb: "sRGB", dcip3: "DCI-P3", dp3: "Display P3", adobe: "Adobe RGB", wide: qsTr("Wide color"), edid: qsTr("EDID color"), hdr: "HDR", hdredid: qsTr("HDR with EDID color")};
        return colors[value] || String(value);
    }
    Repeater {
        model: [{key: "vrr", label: qsTr("Variable refresh rate")}, {key: "bit_depth", label: qsTr("Color depth")}, {key: "color", label: qsTr("Color / HDR")}]
        delegate: Ui.FormField {
            id: choiceRow
            required property var modelData
            Layout.fillWidth: true
            label: modelData.label
            Ui.DropDownList {
                objectName: "displayAdvanced-" + choiceRow.modelData.key
                readonly property string field: choiceRow.modelData.key
                Layout.fillWidth: true
                interactive: card.editable && (card.choices[field] || []).length > 0
                options: [{value: "", label: qsTr("Keep current (%1)").arg(card.label(field, card.observed[field]))}].concat((card.choices[field] || []).map(v => ({value: String(v), label: card.label(field, v)})))
                value: card.draft[field] === undefined ? "" : String(card.draft[field])
                onSelected: value => card.controller.editAdvanced(card.output.name, field, value === "" ? null : field === "vrr" ? value === "true" : field === "bit_depth" ? Number(value) : value)
            }
        }
    }
    Repeater {
        model: [{key: "sdr_brightness", label: qsTr("SDR brightness"), min: 0.1, max: 3}, {key: "sdr_saturation", label: qsTr("SDR saturation"), min: 0, max: 2}]
        delegate: Ui.FormField {
            id: numberRow
            required property var modelData
            Layout.fillWidth: true
            visible: ["hdr", "hdredid"].includes(card.colorPreset)
            label: modelData.label
            Ui.TextField {
                objectName: "displayAdvanced-" + numberRow.modelData.key
                readonly property string field: numberRow.modelData.key
                Layout.fillWidth: true
                enabled: card.editable && card.choices[field] === true
                text: String(card.draft[field] === undefined ? card.observed[field] === undefined ? "" : card.observed[field] : card.draft[field])
                inputValid: text.trim().length > 0 && Number.isFinite(Number(text)) && Number(text) >= numberRow.modelData.min && Number(text) <= numberRow.modelData.max
                onEdited: value => {
                    const number = Number(value);
                    if (value.trim().length && Number.isFinite(number) && number >= numberRow.modelData.min && number <= numberRow.modelData.max)
                        card.controller.editAdvanced(card.output.name, field, number);
                }
            }
        }
    }
}
