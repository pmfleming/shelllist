pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Ui.ActionDetailsPane {
    id: pane
    required property AgendaController controller
    readonly property var item: controller.selectedItem
    readonly property bool writable: controller.canWrite(item)
    readonly property var eventFields: [{key: "location", label: qsTr("Location")}, {key: "people", label: qsTr("People")}, {key: "status", label: qsTr("Status")}]
    readonly property var taskFields: [{key: "priority", label: qsTr("Priority")}, {key: "status", label: qsTr("Status")}]
    objectName: "agendaItemDetails"
    chooserController: controller
    emptyText: qsTr("Select an item")
    title: pane.controller.creating ? qsTr("New item") : item?.title || ""
    subtitle: item?.kind === "task" ? qsTr("Task") : qsTr("Event")
    icon: item?.kind === "task" ? "checklist" : "calendar_month"
    actions: controller.detailActions
    function timestamp(value: var): string { return Number.isSafeInteger(value) ? new Date(value).toLocaleString(Qt.locale(), Locale.ShortFormat) : "—"; }
    function provenanceTimestamp(value: var): string {
        // The current read-only ICS adapter uses epoch zero as an unknown
        // provenance sentinel. Local epoch timestamps remain real observations.
        return value === 0 && item?.source_id !== "local" && item?.capabilities.write === false ? qsTr("Unknown") : timestamp(value);
    }
    function value(key: string, fallback: var): var { return controller.valueFor(item, key, fallback); }
    function changeCollection(key: string, id: string, field: string, value: var): void {
        const values = controller.copy(pane.value(key, key === "links" ? item.links : item.task.checklist));
        const index = values.findIndex(value => value.id === id);
        if (index < 0) return;
        values[index][field] = value;
        controller.saveField(key, values);
    }
    function moveCollection(key: string, id: string, delta: int): void {
        const values = controller.copy(pane.value(key, key === "links" ? item.links : item.task.checklist));
        const index = values.findIndex(value => value.id === id);
        if (index < 0 || index + delta < 0 || index + delta >= values.length) return;
        const value = values.splice(index, 1)[0]; values.splice(index + delta, 0, value);
        controller.saveField(key, values);
    }
    function removeCollection(key: string, id: string): void {
        const values = controller.copy(pane.value(key, key === "links" ? item.links : item.task.checklist));
        const index = values.findIndex(value => value.id === id);
        if (index < 0) return;
        values.splice(index, 1); controller.saveField(key, values);
    }
    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.controlHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: pane.controller.creating ? [] : [{value: "details", icon: "edit", label: qsTr("Details")},
            {value: "notes", icon: "article", label: qsTr("Notes")}, {value: "information", icon: "info", label: qsTr("Information")}]
        onSelected: function(value) { pane.controller.setDetailsTab(value); }
        Loader {
            anchors.fill: parent
            sourceComponent: pane.controller.creating ? creation : pane.item?.summary === true ? unavailable : pane.controller.detailsTab === "details" ? details : pane.controller.detailsTab === "notes" ? notes : information
        }
    }
    Component {
        id: creation
        AgendaCreateEditor { controller: pane.controller }
    }
    Component {
        id: unavailable
        Ui.CenteredMessage { text: pane.controller.detailError || qsTr("Loading item details…") }
    }
    Component {
        id: details
        Ui.DetailFlickable {
            viewMemory: pane.controller.viewMemory
            memoryTab: "details"
            revealFocusedControl: true
            Ui.FormField {
                width: parent.width
                label: qsTr("Title")
                Ui.TextField {
                    id: titleEditor
                    objectName: "agendaTitle"
                    Layout.fillWidth: true
                    readOnly: !pane.writable
                    text: pane.value("title", pane.item?.title || "")
                    onEdited: function(value) { titleTransaction.save(value); }
                    AgendaInlineEdit {
                        id: titleTransaction
                        objectName: "agendaInlineEdit"
                        controller: pane.controller
                        session: titleEditor.editSession
                        fieldKey: "title"
                    }
                }
            }
            Ui.FormField {
                width: parent.width
                visible: !pane.controller.scheduleOpen
                label: qsTr("Schedule")
                supportingText: qsTr("Edit schedule (Alt+E) saves optional endpoints and timezone atomically. Blank endpoints remain blank.")
                Ui.TextField {
                    Layout.fillWidth: true
                    readOnly: true
                    text: pane.item?.schedule.mode === "timed" ? [pane.item.schedule.start_unix_ms === null ? "" : new Date(pane.item.schedule.start_unix_ms).toISOString(), pane.item.schedule.end_unix_ms === null ? "" : new Date(pane.item.schedule.end_unix_ms).toISOString(), pane.item.schedule.timezone || ""].filter(Boolean).join(" — ") : [pane.item?.schedule.start_date || "", pane.item?.schedule.end_date || ""].filter(Boolean).join(" — ")
                }
            }
            Loader {
                width: parent.width
                active: pane.controller.scheduleOpen
                visible: active
                sourceComponent: Component {
                    AgendaScheduleEditor {
                        enabled: !pane.controller.mutationBusy && !pane.controller.scheduleParsing
                        schedule: pane.controller.scheduleDraft
                        scheduleText: pane.controller.scheduleText
                        onChanged: function(value) { pane.controller.scheduleRaw = value; }
                    }
                }
            }
            Repeater {
                model: pane.item?.kind === "event" ? pane.eventFields : pane.taskFields
                Ui.FormField {
                    id: detailField
                    required property var modelData
                    readonly property string group: pane.item?.kind === "event" ? "event" : "task"
                    readonly property string key: group + "." + modelData.key
                    width: parent.width
                    label: modelData.label
                    supportingText: modelData.key === "people" ? qsTr("One person per line; this does not send invitations") : ""
                    Ui.TextEditor {
                        id: detailEditor
                        objectName: "agendaField::" + detailField.key
                        Layout.fillWidth: true
                        readOnly: !pane.writable
                        text: {
                            const value = pane.value(detailField.key, pane.item?.[detailField.group]?.[detailField.modelData.key] ?? "");
                            return Array.isArray(value) ? value.join("\n") : String(value);
                        }
                        onEdited: function(value) {
                            const key = detailField.modelData.key;
                            detailTransaction.save(key === "people" ? value.split("\n").filter(Boolean) : key === "priority" && /^-?\d+$/.test(value) && Number.isSafeInteger(Number(value)) ? Number(value) : value);
                        }
                        AgendaInlineEdit {
                            id: detailTransaction
                            objectName: "agendaInlineEdit"
                            controller: pane.controller
                            session: detailEditor.editSession
                            fieldKey: detailField.key
                        }
                    }
                }
            }
            Ui.ToggleRow {
                width: parent.width
                visible: pane.item?.kind === "task"
                enabled: pane.controller.canComplete(pane.item)
                title: qsTr("Completed")
                checked: pane.item?.task?.completed || false
                onClicked: pane.controller.complete(pane.item)
            }
        }
    }
    Component {
        id: notes
        Ui.DetailFlickable {
            id: notesPage
            Core.KeyedListModel {
                id: linkRows
                values: linksPager.visibleItems.map(link => ({key: pane.item.id + ":" + link.id, payload: link}))
            }
            Core.KeyedListModel {
                id: stepRows
                values: stepsPager.visibleItems.map(step => ({key: pane.item.id + ":" + step.id, payload: step}))
            }
            function turnPage(pager: Ui.CollectionPager, offset: int): void {
                if (pane.controller.navigationBlocked || pane.controller.mutationBusy) return;
                pane.controller.detailsClosing();
                pager.showPage(offset);
                Qt.callLater(function() {
                    if (!notesPage || notesPage.tearingDown || !pager) return;
                    notesPage.revealItem(pager);
                    notesPage.contentY = Math.max(0, Math.min(notesPage.contentHeight - notesPage.height, pager.mapToItem(notesPage.contentItem, 0, 0).y));
                });
            }
            viewMemory: pane.controller.viewMemory
            memoryTab: "notes"
            revealFocusedControl: true
            Ui.FormField {
                width: parent.width
                label: qsTr("Notes")
                Ui.TextEditor {
                    id: notesEditor
                    objectName: "agendaNotes"
                    Layout.fillWidth: true
                    readOnly: !pane.writable
                    text: pane.value("notes", pane.item?.notes || "")
                    onEdited: function(value) { notesTransaction.save(value); }
                    AgendaInlineEdit {
                        id: notesTransaction
                        objectName: "agendaInlineEdit"
                        controller: pane.controller
                        session: notesEditor.editSession
                        fieldKey: "notes"
                    }
                }
            }
            Ui.CollectionPager {
                id: linksPager
                objectName: "agendaLinkPages"
                viewMemory: pane.controller.viewMemory
                memoryTab: "notes"
                memoryKey: "links"
                width: parent.width
                title: qsTr("Links")
                items: pane.value("links", pane.item?.links || [])
                contextKey: pane.item?.id || ""
                blocked: pane.controller.navigationBlocked || pane.controller.mutationBusy
                onPageRequested: function(offset) { notesPage.turnPage(linksPager, offset); }
            }
            Repeater {
                model: linkRows
                Column {
                    id: link
                    required property var resultData
                    readonly property var modelData: resultData.payload
                    width: parent.width
                    Binding {
                        target: linksPager
                        property: "pinnedKey"
                        value: link.modelData.id
                        when: linkLabelEditor.editSession.active || linkUrlEditor.editSession.active
                        restoreMode: Binding.RestoreBindingOrValue
                    }
                    Ui.FormField {
                        width: parent.width
                        label: qsTr("Label")
                        Ui.TextField {
                            id: linkLabelEditor
                            objectName: "agendaLinkLabel::" + link.modelData.id
                            Layout.fillWidth: true
                            readOnly: !pane.writable
                            text: link.modelData.label
                            onEdited: function(value) { linkLabelTransaction.save(value); }
                            AgendaInlineEdit {
                                id: linkLabelTransaction
                                objectName: "agendaInlineEdit"
                                controller: pane.controller
                                session: linkLabelEditor.editSession
                                fieldKey: "links"
                                childId: link.modelData.id
                                childField: "label"
                            }
                        }
                    }
                    Ui.FormField {
                        width: parent.width
                        label: qsTr("URL")
                        Ui.TextField {
                            id: linkUrlEditor
                            objectName: "agendaLinkUrl::" + link.modelData.id
                            Layout.fillWidth: true
                            readOnly: !pane.writable
                            text: link.modelData.url
                            onEdited: function(value) { linkUrlTransaction.save(value); }
                            AgendaInlineEdit {
                                id: linkUrlTransaction
                                objectName: "agendaInlineEdit"
                                controller: pane.controller
                                session: linkUrlEditor.editSession
                                fieldKey: "links"
                                childId: link.modelData.id
                                childField: "url"
                            }
                        }
                    }
                    Ui.FlatIconButton {
                        objectName: "agendaRemoveLink::" + link.modelData.id
                        icon: "delete"
                        accessibleName: qsTr("Remove link %1").arg(link.modelData.label)
                        enabled: pane.writable
                        onClicked: pane.removeCollection("links", link.modelData.id)
                    }
                }
            }
            Ui.FlatIconButton {
                objectName: "agendaAddLink"
                icon: "link"
                accessibleName: qsTr("Add link")
                enabled: pane.writable
                onClicked: pane.controller.openCollection("links")
            }
            Ui.CollectionPager {
                id: stepsPager
                objectName: "agendaStepPages"
                viewMemory: pane.controller.viewMemory
                memoryTab: "notes"
                memoryKey: "checklist"
                width: parent.width
                visible: pane.item?.kind === "task"
                title: qsTr("Checklist")
                items: pane.value("task.checklist", pane.item?.task?.checklist || [])
                contextKey: pane.item?.id || ""
                blocked: pane.controller.navigationBlocked || pane.controller.mutationBusy
                onPageRequested: function(offset) { notesPage.turnPage(stepsPager, offset); }
            }
            Repeater {
                model: stepRows
                Column {
                    id: step
                    required property var resultData
                    readonly property var modelData: resultData.payload
                    readonly property int collectionIndex: stepsPager.items.findIndex(value => value.id === modelData.id)
                    width: parent.width
                    Binding {
                        target: stepsPager
                        property: "pinnedKey"
                        value: step.modelData.id
                        when: stepEditor.editSession.active
                        restoreMode: Binding.RestoreBindingOrValue
                    }
                    Ui.FormField {
                        width: parent.width
                        label: qsTr("Step")
                        Ui.TextField {
                            id: stepEditor
                            objectName: "agendaStep::" + step.modelData.id
                            Layout.fillWidth: true
                            readOnly: !pane.writable
                            text: step.modelData.text
                            onEdited: function(value) { stepTransaction.save(value); }
                            AgendaInlineEdit {
                                id: stepTransaction
                                objectName: "agendaInlineEdit"
                                controller: pane.controller
                                session: stepEditor.editSession
                                fieldKey: "task.checklist"
                                childId: step.modelData.id
                                childField: "text"
                            }
                        }
                    }
                    Ui.ToggleRow {
                        objectName: "agendaStepChecked::" + step.modelData.id
                        width: parent.width
                        title: qsTr("Checked")
                        enabled: pane.writable
                        checked: step.modelData.checked
                        onClicked: pane.changeCollection("task.checklist", step.modelData.id, "checked", !checked)
                    }
                    Row {
                        Ui.FlatIconButton { objectName: "agendaStepUp::" + step.modelData.id; icon: "arrow_upward"; accessibleName: qsTr("Move %1 up").arg(step.modelData.text); enabled: pane.writable && step.collectionIndex > 0; onClicked: pane.moveCollection("task.checklist", step.modelData.id, -1) }
                        Ui.FlatIconButton { objectName: "agendaStepDown::" + step.modelData.id; icon: "arrow_downward"; accessibleName: qsTr("Move %1 down").arg(step.modelData.text); enabled: pane.writable && step.collectionIndex + 1 < stepsPager.items.length; onClicked: pane.moveCollection("task.checklist", step.modelData.id, 1) }
                        Ui.FlatIconButton { objectName: "agendaRemoveStep::" + step.modelData.id; icon: "delete"; accessibleName: qsTr("Remove %1").arg(step.modelData.text); enabled: pane.writable; onClicked: pane.removeCollection("task.checklist", step.modelData.id) }
                    }
                }
            }
            Ui.FlatIconButton {
                visible: pane.item?.kind === "task"
                objectName: "agendaAddStep"
                icon: "add"
                accessibleName: qsTr("Add checklist step")
                enabled: pane.writable
                onClicked: pane.controller.openCollection("task.checklist")
            }
        }
    }
    Component {
        id: information
        Ui.DetailFlickable {
            viewMemory: pane.controller.viewMemory
            memoryTab: "information"
            Repeater {
                model: [
                    {key: "source", label: qsTr("Source"), value: pane.item?.source_id || ""},
                    {key: "source-uid", label: qsTr("Source UID"), value: pane.item?.source_uid || "—"},
                    {key: "identity", label: qsTr("Identity"), value: pane.item?.id || ""},
                    {key: "revision", label: qsTr("Revision"), value: String(pane.item?.revision ?? "")},
                    {key: "capabilities", label: qsTr("Capabilities"), value: [pane.item?.capabilities.write ? qsTr("Editable") : qsTr("Read-only"), pane.item?.capabilities.delete ? qsTr("Can delete") : qsTr("Cannot delete"), pane.item?.capabilities.complete ? qsTr("Can complete") : ""].filter(Boolean).join(" · ")},
                    {key: "created", label: qsTr("Created"), value: pane.provenanceTimestamp(pane.item?.created_unix_ms)},
                    {key: "modified", label: qsTr("Modified"), value: pane.provenanceTimestamp(pane.item?.modified_unix_ms)},
                    {key: "completed", label: qsTr("Completed"), value: pane.timestamp(pane.item?.task?.completed_unix_ms)}
                ].filter(field => (field.label !== qsTr("Source UID") || !!pane.item?.source_uid) && (field.label !== qsTr("Completed") || pane.item?.kind === "task"))
                Ui.DetailField {
                    required property var modelData
                    objectName: "agendaInformation::" + modelData.key
                    width: parent.width
                    label: modelData.label
                    value: modelData.value
                }
            }
        }
    }
}
