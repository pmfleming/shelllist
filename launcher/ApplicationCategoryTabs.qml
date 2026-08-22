import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences

Ui.SegmentedControl {
    required property ApplicationController controller

    options: [{ value: "", label: "All" }].concat(Preferences.categories.map(function (entry) {
        return { value: entry.value, label: entry.label };
    }))
    value: controller.categoryFilter
    interactive: !controller.operationBlocked
    onSelected: function (value) { controller.selectCategory(value); }
}
