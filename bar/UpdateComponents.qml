pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.DetailColumnCard {
    id: card
    required property UpdateController controller
    property bool informationOnly: true
    title: qsTr("Components")
    visible: !!controller.selectedRun && controller.selectedRun.components.length > 0
    Ui.ThemeText {
        objectName: "updateComponentCount"
        Layout.fillWidth: true
        text: Presentation.componentCount(card.controller.selectedRun)
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    Repeater {
        model: Presentation.componentGroups(card.controller.selectedRun)
        ColumnLayout {
            id: group
            required property var modelData
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            Ui.SectionHeading {
                objectName: "updateComponentGroup:" + group.modelData.key
                Layout.fillWidth: true
                title: group.modelData.title + " · " + group.modelData.parts.length
            }
            Repeater {
                model: group.modelData.parts
                Ui.FieldRow {
                    id: partRow
                    required property var modelData
                    objectName: "updateComponent:" + modelData.name
                    label: modelData.name
                    subtitle: Presentation.label(modelData.phase) + (modelData.error && modelData.changed ? " · " + qsTr("Changed before failure") : "")
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Ui.Theme.spacingXs
                        Ui.ThemeText {
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                            text: qsTr("Before: %1").arg(Presentation.shortVersion(partRow.modelData.before))
                        }
                        Ui.ThemeText {
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                            text: qsTr("After: %1").arg(Presentation.shortVersion(partRow.modelData.after))
                        }
                        Ui.ThemeText {
                            Layout.fillWidth: true
                            visible: !!text
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: Ui.Theme.danger
                            text: partRow.modelData.error || ""
                        }
                    }
                    accessories: Ui.FlatIconButton {
                        objectName: "updateCopyComponent:" + partRow.modelData.name
                        sizeRole: "secondary"
                        uiScale: Ui.Theme.expandedSecondaryActionScale
                        icon: "content_copy"
                        accessibleName: qsTr("Copy %1 versions and diagnostics").arg(partRow.modelData.name)
                        Accessible.description: Presentation.componentSummary(partRow.modelData)
                        onClicked: card.controller.copyComponent(partRow.modelData.runId, partRow.modelData.componentIndex)
                    }
                }
            }
        }
    }
}
