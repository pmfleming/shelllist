import QtQuick
import Shelllist.Ui as Ui

Flickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing

    contentWidth: width
    contentHeight: cards.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true

    Column {
        id: cards
        width: page.width
        spacing: Ui.Theme.spacingMd

        Ui.DetailCard {
            height: 440
            title: "Adapter settings"

            BluetoothAdapterSettings {
                id: settings
                anchors.fill: parent
                controller: page.controller
            }
        }

        Ui.DetailCard {
            height: 150
            title: "Adapter details"

            Ui.DetailGrid {
                entries: [
                    { label: "Controller", value: page.controller.selectedAdapter.name || "Unavailable" },
                    { label: "Alias", value: page.controller.selectedAdapter.alias || "Unavailable" },
                    { label: "Address", value: page.controller.selectedAdapter.address || "Unavailable" },
                    { label: "Modalias", value: page.controller.selectedAdapter.modalias || "Unavailable" }
                ]
            }
        }
    }
}
