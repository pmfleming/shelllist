pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.PointerActionControl {
    id: locationCard
    pointerEnabled: enabled

    required property var modelData
    required property string selectedId
    signal selected(string locationId)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Weather for %1").arg(modelData.location || "")
    onClicked: selected(modelData.id)

    radius: Ui.Theme.controlRadius
    color: locationCard.selectedId === modelData.id ? Ui.Theme.selected : Ui.Theme.surfaceRaised
    border.width: locationCard.selectedId === modelData.id ? 2 : 1
    border.color: locationCard.selectedId === modelData.id ? Ui.Theme.accent : Ui.Theme.border

    Ui.ThemeText {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.topMargin: 7
        width: parent.width - 68
        text: locationCard.modelData.location || "—"
        elide: Text.ElideRight
        font.pixelSize: Ui.Theme.fontSizeSmall
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Ui.ThemeText {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 9
        anchors.topMargin: 7
        text: (locationCard.modelData.home ? "⌂  " : "") + (locationCard.modelData.display?.time || "—")
        color: locationCard.modelData.home ? Ui.Theme.accent : Ui.Theme.subtleText
        font.pixelSize: Ui.Theme.metadataSize
    }

    WeatherIcon {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 9
        anchors.bottomMargin: 5
        width: 53
        height: 53
        conditionCode: locationCard.modelData.condition_code ?? -1
        daytime: locationCard.modelData.is_day !== false
        description: locationCard.modelData.condition || ""
    }

    Ui.ThemeText {
        anchors.left: parent.left
        anchors.leftMargin: 68
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 12
        text: locationCard.modelData.display?.temperature || "—"
        font.pixelSize: Ui.Theme.heroReadingSize
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 9
        anchors.bottomMargin: 8
        spacing: 1
        Ui.ThemeText {
            anchors.right: parent.right
            text: (locationCard.modelData.display?.high || "—") + "  " + (locationCard.modelData.display?.low || "—")
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.metadataSize
        }
        Row {
            anchors.right: parent.right
            spacing: 2
            Image {
                width: 13
                height: 13
                source: "assets/weather/raindrop.svg"
                fillMode: Image.PreserveAspectFit
            }
            Ui.ThemeText {
                text: locationCard.modelData.display?.precipitation || "—"
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.metadataSize
            }
        }
    }
}
