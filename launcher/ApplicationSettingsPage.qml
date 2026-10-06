pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences

Ui.DetailFlickable {
    id: page
    objectName: "applicationSettingsPage"
    viewMemory: controller.viewMemory
    memoryTab: "settings"

    required property ApplicationController controller
    required property var application
    readonly property var selectedCategory: {
        const category = Preferences.categories.find(function (entry) {
            return entry.value === page.application.category;
        });
        return category && String(page.application.default_workspace_id || "") === category.workspace ? category : null;
    }
    // Catalog categories can be inferred without a saved workspace preference.
    // Only a present but inconsistent mapping needs repair, not an inferred one.
    readonly property bool mappingNeedsAttention: !!application.default_workspace_id && !selectedCategory
    readonly property var feedback: controller.settingsFeedback.targetId === application.id ? controller.settingsFeedback : ({})
    readonly property var requestedCategory: Preferences.categories.find(category => category.value === page.feedback.category)
    readonly property string categoryError: feedback.error
        ? qsTr("Couldn’t save %1. %2 Choose again to retry.").arg(requestedCategory ? requestedCategory.label : qsTr("category")).arg(feedback.error) : ""
    readonly property var categoryOptions: Preferences.categories.map(function (category) {
        return {value: category.value, label: category.label, icon: category.icon};
    })

    Ui.FormField {
        objectName: "applicationCategoryField"
        width: parent.width
        label: qsTr("Workspace category")
        reserveSupportingSpace: true
        supportingText: page.selectedCategory ? page.selectedCategory.description
            : page.mappingNeedsAttention ? qsTr("Category mapping needs attention. Choose a category to update it.")
            : qsTr("No workspace category assigned.")
        statusText: page.controller.settingsInFlight && page.requestedCategory
            ? qsTr("Saving %1… Showing the last confirmed category.").arg(page.requestedCategory.label) : ""

        Ui.DropDownList {
            objectName: "applicationCategory"
            Layout.fillWidth: true
            options: page.categoryOptions
            value: page.selectedCategory ? page.selectedCategory.value : ""
            placeholder: qsTr("Choose a category")
            errorText: page.categoryError
            interactive: !page.controller.settingsInFlight
            onSelected: function (value) {
                page.controller.updateApplicationSettings(value);
            }
        }
    }

    Ui.DetailSection {
        objectName: "applicationCategoryEffect"
        informationOnly: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            Ui.GlyphLabel {
                Layout.alignment: Qt.AlignTop
                glyph: "desktop_windows"
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.formIconSize
                Accessible.ignored: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingXs
                Ui.ThemeText {
                    objectName: "applicationCategoryConsequence"
                    Layout.fillWidth: true
                    text: page.selectedCategory ? qsTr("New windows open in this category’s workspace.")
                        : page.mappingNeedsAttention ? qsTr("Update the category to set where new windows open.")
                        : qsTr("Choose where new windows open.")
                    wrapMode: Text.Wrap
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: qsTr("Existing windows stay where they are.")
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.formSupportSize
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
