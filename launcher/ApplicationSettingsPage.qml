pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences

Ui.DetailFlickable {
    id: page

    required property ApplicationController controller
    required property var application
    readonly property var selectedCategory: {
        const category = Preferences.categories.find(function (entry) {
            return entry.value === page.application.category;
        });
        return category
            && String(page.application.default_workspace_id || "") === category.workspace
            ? category : null;
    }
    readonly property var categoryOptions: Preferences.categories.map(function (category) {
        return {
            value: category.value,
            label: category.icon + "  " + category.label + " · Workspace " + category.workspace
        };
    })

    Ui.ThemeText {
        width: parent.width
        text: "Choose the application's category. Categories map directly to the first five workspaces, so this also sets where new windows launch."
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
    }

    Ui.DetailColumnCard {
        height: 150
        title: qsTr("Category & default workspace")
        contentSpacing: Ui.Theme.spacingSm

        Ui.DropDownList {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: page.categoryOptions
            value: page.selectedCategory ? page.selectedCategory.value : ""
            placeholder: "Select a category"
            interactive: !page.controller.settingsInFlight
            onSelected: function (value) {
                page.controller.updateApplicationSettings(value);
            }
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            text: page.selectedCategory
                ? page.selectedCategory.description
                : "Choose the category used to place new windows."
            color: Ui.Theme.subtleText
            elide: Text.ElideRight
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }

    Ui.ThemeText {
        width: parent.width
        text: page.application.default_workspace_id
            ? "New windows launch on workspace "
                + page.application.default_workspace_id + ". Existing windows are not moved."
            : "No default workspace is set yet. Select a category to configure one."
        color: Ui.Theme.subtleText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
