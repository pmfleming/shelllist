import QtQuick
import QtQuick.Layouts
import Shelllist.Ui
import "WifiPresentation.js" as Presentation

RowLayout {
    id: header

    required property WifiController controller
    required property real uiScale
    required property real controlHeight
    readonly property var ap: controller.detailAp
    readonly property string connectionLabel: Presentation.connectionStateLabel(controller, ap)
    readonly property bool signInRequired: Presentation.connectivityRequiresSignIn(Presentation.activeConnectivity(controller))
    readonly property color connectionColor: signInRequired ? Theme.warning : Theme.active
    readonly property string lastSeenLabel: Presentation.lastSeenLabel(ap)

    spacing: 14

    Item {
        Layout.preferredWidth: 58
        Layout.preferredHeight: 54
        Layout.alignment: Qt.AlignVCenter

        SignalIcon {
            anchors.centerIn: parent
            width: Math.round(48 * header.uiScale)
            height: Math.round(40 * header.uiScale)
            level: 3
            iconColor: Theme.accent
        }
    }

    Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 7

        Text {
            width: parent.width
            text: Presentation.networkName(header.ap)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(22 * header.uiScale)
            font.bold: true
            elide: Text.ElideRight
        }

        Row {
            height: 18
            spacing: 8

            Rectangle {
                visible: header.controller.isActive(header.ap)
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: width / 2
                color: header.connectionColor
            }
            Text {
                visible: header.connectionLabel.length > 0
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: header.connectionLabel
                color: header.controller.isActive(header.ap) ? header.connectionColor : Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                visible: header.connectionLabel.length > 0 && header.lastSeenLabel.length > 0
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "/"
                color: Theme.subtleText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                visible: header.lastSeenLabel.length > 0
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: header.lastSeenLabel
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Item {
        Layout.preferredWidth: 156
        Layout.preferredHeight: header.controlHeight
        Layout.alignment: Qt.AlignVCenter

        NetworkDetailsActions {
            anchors.fill: parent
            controller: header.controller
            primaryOnly: true
            alignRight: true
            controlHeight: header.controlHeight
        }
    }
}
