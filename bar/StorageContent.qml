pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PanelSurface {
    id: content
    required property StorageController controller
    chooserController: controller
    navigationContent: list
    feedbackEnabled: true
    feedbackText: controller.errorText || (controller.snapshot && controller.snapshot.errors.length ? controller.snapshot.errors.join("\n") : "")
    feedbackSummary: qsTr("Storage inventory needs attention")
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd
        RowLayout {
            Layout.fillWidth: true
            Ui.ThemeText { Layout.fillWidth: true; text: qsTr("Storage"); font.pixelSize: Ui.Theme.fontSizeTitle; font.weight: Ui.Theme.fontWeightBold }
            Ui.ActionButton { objectName: "storageScan"; label: qsTr("Scan storage"); icon: "refresh"; accessKey: "S"; enabled: content.controller.canAct; onClicked: content.controller.scan() }
            Ui.ActionButton { objectName: "storageClean"; label: qsTr("Clean eligible caches now"); icon: "cleaning_services"; accessKey: "C"; enabled: content.controller.canAct && content.controller.eligibleBytes > 0; onClicked: content.controller.clean() }
            Ui.ActionButton { objectName: "storageCancel"; label: qsTr("Cancel storage operation"); icon: "stop"; accessKey: "X"; enabled: content.controller.busy; onClicked: content.controller.cancel() }
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: content.controller.busy ? qsTr("%1 in progress").arg(content.controller.storageState.busy)
                : content.controller.snapshot ? qsTr("%1 available · %2 eligible for cleanup").arg(content.controller.bytes(content.controller.snapshot.filesystem_available)).arg(content.controller.bytes(content.controller.eligibleBytes))
                : qsTr("Scan to measure usage and preview cleanup")
            wrapMode: Text.Wrap
        }
        Ui.DetailListView {
            id: list
            objectName: "storageList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            viewMemory: content.controller.viewMemory
            memoryTab: content.controller.viewTab
            cacheBuffer: 0
            reuseItems: true
            spacing: Ui.Theme.spacingMd
            model: content.controller.rows
            header: Column {
                width: list.rowWidth
                spacing: Ui.Theme.spacingMd
                Ui.ThemeText {
                    width: parent.width
                    visible: content.controller.viewTab !== "policy"
                    text: content.controller.viewTab === "cleanup" ? qsTr("Only recognized generated caches are eligible. Source files, active builds and pinned projects are preserved. Reclaimed space can be lower than this estimate.")
                        : content.controller.viewTab === "history" ? qsTr("Completed and interrupted cleanups; bytes are confirmed removals.")
                        : qsTr("Allocated bytes, with hard links counted once. Nix store, system temporary files, journals and other owners are measured only.")
                    wrapMode: Text.Wrap
                }
                Ui.ThemeText {
                    width: parent.width
                    visible: !!content.controller.snapshot && content.controller.viewTab !== "policy"
                    text: content.controller.snapshot ? qsTr("Measured %1 · %2").arg(new Date(content.controller.snapshot.scanned_at * 1000).toLocaleString()).arg(content.controller.snapshot.complete ? qsTr("complete") : qsTr("partial coverage")) : ""
                    wrapMode: Text.Wrap
                }
                Column {
                    width: parent.width
                    visible: content.controller.viewTab === "policy"
                    spacing: Ui.Theme.spacingMd
                    Ui.ToggleRow {
                        objectName: "storageShutdown"
                        title: qsTr("Clean caches at shutdown")
                        subtitle: qsTr("Automatic cleanup runs after user sessions stop")
                        checked: content.controller.policy ? content.controller.policy.shutdown_enabled : false
                        enabled: content.controller.canAct && !!content.controller.policy
                        onClicked: content.controller.savePolicy("shutdown_enabled", !checked)
                    }
                    Repeater {
                        model: [
                            {key: "project_budget_gib", label: qsTr("Project cache budget"), unit: "GiB", values: [8,16,32,64,128,256,512]},
                            {key: "shared_budget_gib", label: qsTr("Shared cache budget"), unit: "GiB", values: [1,2,4,8,16,32,64]},
                            {key: "warm_hours", label: qsTr("Keep recent artifacts"), unit: qsTr("hours"), values: [1,6,12,24,48,72,168]},
                            {key: "retention_days", label: qsTr("Inactive cache retention"), unit: qsTr("days"), values: [1,7,14,30,60,90]},
                            {key: "log_retention_days", label: qsTr("Completed log retention"), unit: qsTr("days"), values: [7,14,30,60,90]}
                        ]
                        Ui.FieldRow {
                            id: setting
                            required property var modelData
                            width: parent.width
                            label: modelData.label
                            Ui.DropDownList {
                                objectName: "storagePolicy:" + setting.modelData.key
                                Layout.fillWidth: true
                                value: content.controller.policy ? String(content.controller.policy[setting.modelData.key]) : ""
                                options: setting.modelData.values.map(v => ({value: String(v), label: v + " " + setting.modelData.unit}))
                                interactive: content.controller.canAct && !!content.controller.policy
                                onSelected: function(value) { content.controller.savePolicy(setting.modelData.key, Number(value)); }
                            }
                        }
                    }
                    Ui.FieldRow {
                        width: parent.width
                        label: qsTr("Pinned projects")
                        subtitle: qsTr("Absolute paths, separated by semicolons")
                        Ui.TextField {
                            objectName: "storagePins"
                            Layout.fillWidth: true
                            text: content.controller.policy ? content.controller.policy.excluded_projects.join("; ") : ""
                            enabled: content.controller.canAct && !!content.controller.policy
                            onEditingFinished: content.controller.savePolicy("excluded_projects", text.split(";").map(p => p.trim()).filter(Boolean))
                        }
                    }
                    Ui.ThemeText { width: parent.width; text: qsTr("Budgets are soft when data is protected. Policy changes update the cleanup preview using the last measurement. Nix garbage collection and temporary-file retention remain managed by NixOS."); wrapMode: Text.Wrap }
                }
            }
            delegate: Ui.FieldRow {
                id: row
                required property var modelData
                width: list.rowWidth
                label: content.controller.viewTab === "history" ? new Date(modelData.started_at * 1000).toLocaleString() : modelData.path
                subtitle: content.controller.viewTab === "history" ? modelData.trigger + (modelData.cancelled ? qsTr(" · interrupted") : "")
                    : content.controller.viewTab === "cleanup" ? modelData.reason : modelData.category
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: content.controller.bytes(content.controller.viewTab === "history" ? row.modelData.reclaimed : row.modelData.bytes)
                        + (content.controller.viewTab === "cleanup" ? (row.modelData.eligible ? qsTr(" · eligible") : qsTr(" · preserved")) : "")
                    wrapMode: Text.Wrap
                    Accessible.description: content.controller.viewTab === "history" ? row.modelData.details.join("\n") : row.modelData.path
                }
            }
        }
        Ui.DetailsTabBar {
            Layout.fillWidth: true
            tabs: content.controller.viewTabs
            selectedValue: content.controller.viewTab
            onSelected: function(value) { content.detailsNavigation.finishEditor(false); content.controller.viewTab = value; }
        }
    }
}
