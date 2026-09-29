import QtQuick
import QtQuick.Layouts
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

DetailFlickable {
    id: cards

    required property WifiController controller
    viewMemory: controller.viewMemory
    memoryTab: "network"
    required property var accessPoint
    required property real sectionSpacing
    required property real connectionCardHeight
    required property real networkCardHeight
    required property real profileCardHeight
    cardSpacing: sectionSpacing

    NetworkProfileSettingsCard {
        objectName: "wifiPrimarySettings"
        controller: cards.controller
        height: cards.profileCardHeight
    }
    DisclosureSection {
        objectName: "wifiNetworkDiagnostics"
        title: qsTr("Connection & network details")
        DetailCard {
            Layout.fillWidth: true
            Layout.preferredHeight: cards.connectionCardHeight
            title: qsTr("Connection")
            entries: Presentation.connectionDetailRows(cards.controller, cards.accessPoint, Theme.accent).slice(0, 8)
        }
        DetailCard {
            Layout.fillWidth: true
            Layout.preferredHeight: cards.networkCardHeight
            title: qsTr("Network details")
            entries: Presentation.networkDetailRows(cards.controller, cards.accessPoint).slice(0, 4)
        }
    }
}
