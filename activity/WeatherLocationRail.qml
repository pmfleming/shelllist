pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: locationRail
    required property var locations
    required property string selectedId
    required property date now
    signal selected(string locationId)

    function revealSelectedLocation(): void {
        const index = locations.findIndex(function (location) {
            return location.id === locationRail.selectedId;
        });
        const card = index >= 0 ? locationRepeater.itemAt(index) : null;
        if (!card)
            return;
        const target = card.x + card.width / 2 - locationFlick.width / 2;
        locationFlick.contentX = Math.max(0, Math.min(target, Math.max(0, locationFlick.contentWidth - locationFlick.width)));
    }
    onSelectedIdChanged: Qt.callLater(revealSelectedLocation)
    onLocationsChanged: Qt.callLater(revealSelectedLocation)
    onWidthChanged: Qt.callLater(revealSelectedLocation)
    Component.onCompleted: Qt.callLater(revealSelectedLocation)
    width: parent.width
    height: 108
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    clip: true

    Flickable {
        id: locationFlick
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingSm
        contentWidth: locationRow.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        interactive: contentWidth > width

        Behavior on contentX {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                duration: Ui.Theme.animationInteractive
                easing.type: Ui.Theme.easingResponsive
            }
        }

        Row {
            id: locationRow
            height: parent.height
            spacing: Ui.Theme.spacingSm

            Repeater {
                id: locationRepeater
                model: locationRail.locations

                delegate: WeatherLocationCard {
                    width: Math.min(220, Math.max(174, (locationRail.width - Ui.Theme.spacingSm * 4) / 3))
                    height: locationRow.height
                    selectedId: locationRail.selectedId
                    now: locationRail.now
                    onSelected: function (locationId) {
                        locationRail.selected(locationId);
                    }
                }
            }
        }
    }
}
