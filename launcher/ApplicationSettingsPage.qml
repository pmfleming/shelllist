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
    cardSpacing: Ui.Theme.cardGap

    required property ApplicationController controller
    required property var application
    readonly property string informationTargetId: application.id || ""
    onInformationTargetIdChanged: settingsInformation.text = ""
    onVisibleChanged: if (!visible) settingsInformation.text = ""
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
    }).concat([{value: "", label: qsTr("Uncategorized"), icon: "category"}])

    Column {
        objectName: "applicationPreferences"
        visible: page.application.kind === "desktop-application"
        width: parent.width
        spacing: Ui.Theme.spacingMd
    Ui.FormField {
        id: categoryField
        objectName: "applicationCategoryField"
        width: parent.width
        label: qsTr("Category")
        icon: "category"
        accessibleName: qsTr("Workspace category")
        showHelpButton: false
        supportingText: page.selectedCategory ? page.selectedCategory.description : qsTr("No workspace category assigned.")
        statusText: page.controller.settingsInFlight && page.requestedCategory
            ? qsTr("Saving %1…").arg(page.requestedCategory.label)
            : page.mappingNeedsAttention ? qsTr("Category mapping needs attention. Choose a category to update it.") : ""

        Ui.DropDownList {
            objectName: "applicationCategory"
            Layout.fillWidth: true
            options: page.categoryOptions
            value: page.selectedCategory ? page.selectedCategory.value : ""
            placeholder: qsTr("Uncategorized")
            saveOnOptionClick: true
            errorText: page.categoryError
            interactive: !page.controller.settingsInFlight
            onSelected: function (value) {
                page.controller.updateApplicationSettings(value);
            }
        }
    }
    Ui.ToggleRow {
        id: newWorkspace
        objectName: "applicationNewWorkspace"
        width: parent.width
        visible: page.application.kind === "desktop-application" && typeof page.application.new_workspace === "boolean"
        title: qsTr("Open on a new workspace")
        subtitle: qsTr("Use a new workspace for launches with default routing.")
        showSubtitle: false
        checked: !!page.application.new_workspace
        interactive: !page.controller.settingsInFlight
        onClicked: {
            // The request disables the switch's pointer area immediately.
            workspaceInformation.disclose();
            page.controller.updateApplicationPreferences({new_workspace: !checked});
        }
    }
    }
    ApplicationDataDetails {
        id: appData
        width: parent.width
        controller: page.controller
        application: page.application
        showHelpButton: false
        contentSpacing: Ui.Theme.spacingMd
    }
    Ui.FeedbackSource {
        id: settingsInformation
        objectName: "applicationSettingsInformation"
        priority: 1
    }
    Ui.FeedbackTapHandler {
        parent: categoryField
        feedback: settingsInformation
        feedbackText: categoryField.helpText
    }
    Ui.FeedbackTapHandler {
        id: workspaceInformation
        parent: newWorkspace
        feedback: settingsInformation
        feedbackText: newWorkspace.subtitle
    }
    Ui.FeedbackTapHandler {
        parent: appData
        feedback: settingsInformation
        feedbackText: appData.helpText
        feedbackSummary: qsTr("Identified app data excludes installation and shared dependencies. Temporary data is not necessarily safe to delete.")
        feedbackBrief: qsTr("App data: identified files only; temporary does not mean safe to delete.")
    }
}
