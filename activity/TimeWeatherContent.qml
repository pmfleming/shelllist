pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property TimeWeatherController controller
    readonly property alias now: liveClock.now

    chooserController: controller
    feedbackScope: content
    navigationEnabled: !controller.screenshotInFlight && !controller.locations.modalOpen
    refreshEnabled: navigationEnabled && !controller.activity.syncing
    commandsWithoutDetails: true
    additionalCommandItem: locationCommands

    Ui.CommandGroup {
        id: locationCommands
        Ui.ActionControl {
            objectName: "timeWeatherAddCommand"
            accessibleName: qsTr("Add city")
            accessKey: "A"
            includeInCommandMenu: true
            activeFocusOnTab: false
            enabled: content.navigationEnabled && content.controller.locations.canAdd
            onClicked: content.controller.locations.openPicker("add")
        }
        Repeater {
            model: content.controller.detailsOpen ? [] : content.controller.detailActions
            Ui.ActionControl {
                required property var modelData
                accessibleName: modelData.label
                accessKey: modelData.accessKey
                includeInCommandMenu: true
                activeFocusOnTab: false
                enabled: content.navigationEnabled && modelData.enabled
                onClicked: content.controller.triggerDetailAction(modelData.id)
            }
        }
    }
    Ui.FeedbackSource {
        objectName: "cityOperationFeedback"
        text: content.controller.locations.error
        summaryText: text
        briefText: qsTr("Location needs attention")
        tone: "error"
    }
    Ui.SearchChoiceDialog {
        objectName: "timeWeatherCityPicker"
        icon: content.controller.locations.pickerMode === "add" ? "add" : "my_location"
        visible: content.controller.locations.pickerMode.length > 0
        title: content.controller.locations.pickerMode === "add" ? qsTr("Add city") : qsTr("Set current location manually")
        detail: content.controller.locations.pickerMode === "manual" ? qsTr("Sets the system timezone and pauses automatic location. Home remains Amsterdam.") : ""
        query: content.controller.locations.query
        choices: content.controller.locations.choiceOptions
        choice: content.controller.locations.choice
        searching: content.controller.locations.searchId.length > 0
        acceptLabel: content.controller.locations.pickerMode === "add" ? qsTr("Add") : qsTr("Set location")
        acceptEnabled: !content.controller.locations.busy && content.controller.locations.validPlace(content.controller.locations.selectedPlace)
        onQueryEdited: function(query) { content.controller.locations.editQuery(query); }
        onChoiceSelected: function(value) { content.controller.locations.selectChoice(value); }
        onAccepted: content.controller.locations.submitPicker()
        onCancelled: content.controller.locations.closeModal()
    }
    Ui.ConfirmationDialog {
        objectName: "timeWeatherRemoveConfirmation"
        visible: content.controller.locations.removal !== null
        title: qsTr("Remove %1?").arg(content.controller.locations.removal?.label || "")
        detail: qsTr("Removes this saved city only. Home and the current location are unchanged.")
        acceptEnabled: !content.controller.locations.busy
        onAccepted: content.controller.locations.confirmRemove()
        onCancelled: content.controller.locations.closeModal()
    }

    listComponent: Component {
        TimeWeatherListPane {
            controller: content.controller
            nowMs: content.now.getTime()
        }
    }
    detailsComponent: Component {
        TimeWeatherDetails {
            controller: content.controller
            now: content.now
            uiScale: content.uiScale
        }
    }

    Ui.FeedbackSource {
        objectName: "locationTimezoneFeedback"
        active: text.length > 0
        text: content.controller.timezone.error || ""
        summaryText: text
        briefText: qsTr("Location needs attention")
        tone: "warning"
    }

    Ui.LiveClock {
        id: liveClock
        active: content.controller.uiActive
        alignToMinute: true
    }
}
