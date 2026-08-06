import QtQuick
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

DetailFlickable {
    id: cards

    required property WifiController controller
    required property var accessPoint
    required property real sectionSpacing
    required property real connectionCardHeight
    required property real networkCardHeight
    required property real profileCardHeight

    cardSpacing: sectionSpacing

    DetailCard {
        height: cards.connectionCardHeight
        title: "Connection"
        entries: Presentation.connectionDetailRows(cards.controller, cards.accessPoint, Theme.accent).slice(0, 8)
    }

    DetailCard {
        height: cards.networkCardHeight
        title: "Network details"
        entries: Presentation.networkDetailRows(cards.controller, cards.accessPoint).slice(0, 4)
    }

    NetworkProfileSettingsCard {
        controller: cards.controller
        height: cards.profileCardHeight
    }
}
