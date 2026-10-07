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
        label: qsTr("Category")
        icon: "category"
        accessibleName: qsTr("Workspace category")
        supportingText: page.selectedCategory ? page.selectedCategory.description : qsTr("No workspace category assigned.")
        statusText: page.controller.settingsInFlight && page.requestedCategory
            ? qsTr("Saving %1…").arg(page.requestedCategory.label)
            : page.mappingNeedsAttention ? qsTr("Category mapping needs attention. Choose a category to update it.") : ""

        Ui.DropDownList {
            objectName: "applicationCategory"
            Layout.fillWidth: true
            options: page.categoryOptions
            value: page.selectedCategory ? page.selectedCategory.value : ""
            placeholder: qsTr("Choose a category")
            saveOnOptionClick: true
            errorText: page.categoryError
            interactive: !page.controller.settingsInFlight
            onSelected: function (value) {
                page.controller.updateApplicationSettings(value);
            }
        }
    }
}
