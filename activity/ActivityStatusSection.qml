pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Column {
    id: section

    required property ActivityController controller
    required property date now

    width: parent.width
    spacing: Ui.Theme.spacingSm

    function worldTime(clock: var): string {
        const shifted = new Date(now.getTime() + Number(clock.utc_offset_seconds || 0) * 1000);
        return String(shifted.getUTCHours()).padStart(2, "0") + ":"
            + String(shifted.getUTCMinutes()).padStart(2, "0");
    }

    Rectangle { width: parent.width; height: 1; color: Ui.Theme.border }
    Text {
        text: "World clocks"
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Repeater {
        model: section.controller.activity.world_clocks || []
        delegate: RowLayout {
            id: worldClockRow
            required property var modelData
            width: parent.width
            height: 30
            Text {
                Layout.fillWidth: true
                text: worldClockRow.modelData.label || worldClockRow.modelData.city
                color: Ui.Theme.text
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
            }
            Text {
                text: section.worldTime(worldClockRow.modelData) + "  "
                    + (worldClockRow.modelData.abbreviation || "")
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
            }
        }
    }
    Text {
        visible: (section.controller.activity.world_clocks || []).length === 0
        text: "Add zones in bar-daemon activity.json"
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Rectangle { width: parent.width; height: 1; color: Ui.Theme.border }
    Text {
        text: "Sources"
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Repeater {
        model: section.controller.activity.sources || []
        delegate: Row {
            id: sourceRow
            required property var modelData
            width: parent.width
            height: 26
            spacing: 7
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 4
                color: sourceRow.modelData.available
                    ? Ui.Theme.active : Ui.Theme.danger
            }
            Text {
                width: parent.width - 56
                text: sourceRow.modelData.name || sourceRow.modelData.id
                color: Ui.Theme.text
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
            Text {
                text: String(sourceRow.modelData.item_count || 0)
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }
}
