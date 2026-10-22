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
    cardSpacing: sectionSpacing

    NetworkProfileSettingsCard {
        objectName: "wifiPrimarySettings"
        controller: cards.controller
    }
    DetailSection {
        informationOnly: true
        objectName: "wifiNetworkDiagnostics"
        DetailCard {
            objectName: "wifiConnectionCard"
            Layout.fillWidth: true
            title: qsTr("Connection")
            entries: Presentation.connectionDetailRows(cards.controller, cards.accessPoint, Theme.accent).slice(0, 8)
        }
        DetailCard {
            objectName: "wifiNetworkDetailsCard"
            Layout.fillWidth: true
            title: qsTr("Network details")
            entries: Presentation.networkDetailRows(cards.controller, cards.accessPoint).slice(0, 4)
        }
    }
}
