pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: locationCard

    required property var modelData
    required property string selectedId
    required property date now
    signal selected(string locationId)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Weather for %1").arg(modelData.location || "")
    Accessible.onPressAction: selected(modelData.id)
    Keys.onReturnPressed: selected(modelData.id)
    Keys.onEnterPressed: selected(modelData.id)
    Keys.onSpacePressed: selected(modelData.id)

    radius: Ui.Theme.controlRadius
    color: locationCard.selectedId === modelData.id
        ? Ui.Theme.selected : Ui.Theme.surfaceRaised
    border.width: locationCard.selectedId === modelData.id ? 2 : 1
    border.color: activeFocus || locationCard.selectedId === modelData.id
        ? Ui.Theme.accent : Ui.Theme.border

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
        text: (locationCard.modelData.home ? "⌂  " : "")
            + Visuals.weatherTime(locationCard.now.getTime(), locationCard.modelData)
        color: locationCard.modelData.home
            ? Ui.Theme.accent : Ui.Theme.subtleText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    WeatherIcon {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 9
        anchors.bottomMargin: 5
        width: 53
        height: 53
        conditionCode: Visuals.conditionCode(locationCard.modelData.condition_code)
        daytime: locationCard.modelData.is_day !== false
        description: locationCard.modelData.condition || ""
    }

    Ui.ThemeText {
        anchors.left: parent.left
        anchors.leftMargin: 68
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 12
        text: Visuals.numberLabel(locationCard.modelData.temperature_c, "°")
        font.pixelSize: 29
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 9
        anchors.bottomMargin: 8
        spacing: 1
        Ui.ThemeText {
            anchors.right: parent.right
            text: Visuals.numberLabel(locationCard.modelData.high_c, "°")
                + "  " + Visuals.numberLabel(locationCard.modelData.low_c, "°")
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
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
                text: Visuals.numberLabel(
                    locationCard.modelData.precipitation_probability, "%")
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            locationCard.forceActiveFocus();
            locationCard.selected(locationCard.modelData.id);
        }
    }
}
