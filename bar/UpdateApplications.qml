pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Rectangle {
    id: page
    required property UpdateController controller
    readonly property var catalog: controller.applicationCatalog
    readonly property bool available: !!catalog
    readonly property string helpText: qsTr("Local shows active and generation package versions separately; Latest shows latest known upstream releases. Shared with the launcher. Refresh only reads.")
    objectName: "updateApplicationsOverview"
    color: Ui.Theme.surface
    radius: Ui.Theme.cardRadius
    Accessible.description: available ? qsTr("%1 software entries").arg(catalog.entries.length) : ""

    Ui.FeedbackSource {
        id: explanation
        objectName: "updateApplicationExplanation"
        priority: 5
        active: page.controller.uiActive && page.controller.detailsOpen
        onActiveChanged: if (!active) text = ""
    }
    onVisibleChanged: if (!visible) explanation.text = ""
    onCatalogChanged: { explanation.text = ""; updatePackages(); }
    Connections {
        target: page.controller
        function onSoftwareRouteChanged(): void { page.updatePackages(); }
        function onSoftwareStateChanged(): void { page.updatePackages(); }
    }
    Component.onCompleted: updatePackages()
    function updatePackages(): void {
        if (!list || !packagesModel) return;
        list.captureAnchor();
        let previous = "";
        const entries = (available ? catalog.entries : []).filter(entry => {
            const installations = entry.installations || [];
            return (!controller.softwareRoute || installations.some(i => i.update_route === controller.softwareRoute))
                && (!controller.softwareState || installations.some(i => i.release_state === controller.softwareState));
        });
        const counts = new Map();
        for (const entry of entries) {
            const group = Ui.SoftwarePresentation.group(entry);
            counts.set(group, (counts.get(group) || 0) + 1);
        }
        packagesModel.rows = entries.map(entry => {
            const group = Ui.SoftwarePresentation.group(entry);
            const start = previous !== group;
            previous = group;
            return {key: entry.id, payload: {record: entry, group: group, groupStart: start, groupCount: counts.get(group)}};
        });
        Qt.callLater(list.restoreAnchor);
    }
    Connections {
        target: page.controller
        function onNavigationInteracted(): void { list.cancelAnchor(); }
    }
    Ui.DetailListView {
        id: list
        objectName: "updateApplicationsList"
        anchors.fill: parent
        anchors.margins: Ui.Theme.cardPadding
        viewMemory: page.controller.viewMemory
        memoryTab: "applications"
        cacheBuffer: 0
        reuseItems: true
        spacing: Ui.Theme.spacingSm
        model: Core.SerializedListModel { id: packagesModel }
        header: Column {
            width: list.rowWidth
            spacing: Ui.Theme.spacingMd
            Ui.SectionHeading {
                width: parent.width
                title: page.available ? qsTr("Software · %1").arg(page.catalog.entries.length) : qsTr("Software")
                helpText: page.helpText
                helpFeedback: explanation
            }
            Ui.ThemeText {
                objectName: "updateApplicationUnavailable"
                width: parent.width
                visible: !!text
                text: page.controller.catalogError || (page.catalog ? page.catalog.error || "" : qsTr("Application catalog not reported"))
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
            Ui.ThemeText {
                width: parent.width
                visible: !!page.catalog && page.catalog.inventory_included < page.catalog.inventory_total
                text: page.catalog ? qsTr("Package coverage: %1 of %2").arg(page.catalog.inventory_included).arg(page.catalog.inventory_total) : ""
                wrapMode: Text.Wrap
            }
            Ui.FieldRow {
                width: parent.width
                label: qsTr("Updated by")
                Ui.DropDownList {
                    objectName: "softwareRouteFilter"
                    Layout.fillWidth: true
                    Accessible.name: qsTr("Filter update route")
                    value: page.controller.softwareRoute
                    options: [{value: "", label: qsTr("All routes")}, {value: "nixos", label: qsTr("NixOS rebuild")},
                        {value: "vendor", label: qsTr("Independent vendor updater")}, {value: "self-updater", label: qsTr("Application updater")},
                        {value: "local", label: qsTr("Local development")}]
                    onSelected: function(value) { page.controller.softwareRoute = value; }
                }
            }
            Ui.FieldRow {
                width: parent.width
                label: qsTr("Release status")
                Ui.DropDownList {
                    objectName: "softwareStateFilter"
                    Layout.fillWidth: true
                    Accessible.name: qsTr("Filter release status")
                    value: page.controller.softwareState
                    options: [{value: "", label: qsTr("All statuses")}, {value: "newer", label: qsTr("Newer upstream")},
                        {value: "current", label: qsTr("Current")}, {value: "failed", label: qsTr("Check failed")},
                        {value: "cached", label: qsTr("Cached")}, {value: "unsupported", label: qsTr("Unsupported")}]
                    onSelected: function(value) { page.controller.softwareState = value; }
                }
            }
            Ui.FieldRow {
                width: parent.width
                height: implicitHeight
                visible: page.available
                label: qsTr("Name")
                separatorVisible: false
                RowLayout {
                    Layout.fillWidth: true
                    Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Installed"); color: Ui.Theme.mutedText }
                    Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Latest upstream"); color: Ui.Theme.mutedText }
                }
            }
        }
        delegate: Column {
            id: row
            required property var resultData
            readonly property var payload: JSON.parse(resultData.payload)
            readonly property var record: payload.record
            property bool pooled: false
            ListView.onPooled: pooled = true
            ListView.onReused: pooled = false
            visible: !pooled
            objectName: pooled ? "" : "updateApplication:" + record.id
            width: list.rowWidth
            spacing: Ui.Theme.spacingSm
            Ui.ThemeText {
                objectName: "softwareGroupHeading"
                width: parent.width
                visible: row.payload.groupStart
                text: row.payload.group + " · " + row.payload.groupCount
                font.pixelSize: Ui.Theme.groupHeadingSize
                font.weight: Ui.Theme.groupHeadingWeight
                color: Ui.Theme.mutedText
                wrapMode: Text.Wrap
            }
            Ui.FieldRow {
                width: parent.width
                height: implicitHeight
                label: row.record.name
                subtitle: Ui.SoftwarePresentation.route(row.record)
                RowLayout {
                    Layout.fillWidth: true
                    Ui.ThemeText {
                        objectName: "updateApplicationLocal"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        text: Ui.SoftwarePresentation.localWithOrigins(row.record)
                        font.pixelSize: Ui.Theme.formValueSize
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        Accessible.name: qsTr("%1: local %2").arg(row.record.name).arg(text)
                        Accessible.description: Ui.SoftwarePresentation.details(row.record)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Ui.ThemeText {
                            objectName: "updateApplicationLatest"
                            Layout.fillWidth: true
                            text: Ui.SoftwarePresentation.latest(row.record)
                            font.pixelSize: Ui.Theme.formValueSize
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                            Accessible.name: Ui.SoftwarePresentation.summary(row.record)
                        }
                        Ui.FeedbackButton {
                            objectName: "updateApplicationStatus"
                            Layout.preferredWidth: Ui.Theme.formActionSize
                            Layout.preferredHeight: Ui.Theme.formActionSize
                            iconSize: Ui.Theme.formActionIconSize
                            icon: Ui.SoftwarePresentation.icon(row.record)
                            accessibleName: qsTr("Version status: %1").arg(row.record.name)
                            Accessible.description: Ui.SoftwarePresentation.summary(row.record) + " " + Ui.SoftwarePresentation.details(row.record)
                            feedback: explanation
                            feedbackText: Ui.SoftwarePresentation.summary(row.record)
                            feedbackBrief: qsTr("Application release status")
                        }
                    }
                }
            }
        }
    }
}
