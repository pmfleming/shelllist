pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothGlyphs.js" as BluetoothGlyphs

ColumnLayout {
    id: section
    required property BluetoothController controller
    readonly property var batteryReports: BluetoothBattery.ordered(controller.selectedDevice.battery || [])
    readonly property string batterySource: BluetoothBattery.sourceLabel(batteryReports)
    Layout.fillWidth: true
    spacing: 10
    RowLayout {
        Layout.fillWidth: true
        spacing: 9
        Text {
            text: section.controller.selectedResult ? section.controller.selectedResult.icon : "󰂯"
            color: section.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.mutedText
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: 23
        }
        Text { Layout.fillWidth: true; text: section.controller.selectedResult ? section.controller.selectedResult.title : "Bluetooth device"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 20; font.bold: true; elide: Text.ElideRight }
    }
    Text { Layout.fillWidth: true; text: section.controller.selectedResult ? section.controller.selectedResult.subtitle : ""; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 12 }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.border }
    Text { text: "Paired        " + (section.controller.selectedDevice.paired ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
    Text { text: "Trusted       " + (section.controller.selectedDevice.trusted ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
    Text { text: "In range      " + (section.controller.selectedDevice.present ? "Yes" : "No"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
    Text { text: "Services      " + (section.controller.selectedDevice.services_resolved ? "Resolved" : "Pending"); color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 13 }
    Text { visible: !!(section.controller.selectedDevice.services && section.controller.selectedDevice.services.length); Layout.fillWidth: true; text: (section.controller.selectedDevice.services || []).map(function (service) { return service.label; }).filter(function (label, index, values) { return values.indexOf(label) === index; }).join(" · "); color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; wrapMode: Text.WordWrap }
    Text {
        visible: section.batteryReports.length > 0
        text: section.batteryReports.length > 1 ? "Component batteries" : "Battery"
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 14
        font.bold: true
    }
    Repeater {
        model: section.batteryReports
        delegate: Rectangle {
            id: batteryCard
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.surfaceRaised
            border.color: Ui.Theme.border
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                Text {
                    text: BluetoothGlyphs.forBattery(batteryCard.modelData)
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: 17
                }
                Text { Layout.fillWidth: true; text: batteryCard.modelData.label || batteryCard.modelData.component || "Battery"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 12 }
                Text { text: batteryCard.modelData.percentage + "%"; color: Ui.Theme.active; font.family: Ui.Theme.fontFamily; font.pixelSize: 14; font.bold: true }
            }
        }
    }
    Text {
        visible: section.batterySource.length > 0
        text: section.batterySource
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 10
    }
    Text {
        visible: !!section.controller.obexCapabilities.available
        text: section.controller.obexCapabilities.outgoing_object_push ? "File transfer  Ready" : "OBEX service   Available · sending staged"
        color: Ui.Theme.subtleText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
    }
    Text {
        visible: !!section.controller.activeAudioProfile.label
        Layout.fillWidth: true
        text: "Audio          " + (section.controller.activeAudioProfile.codec || section.controller.activeAudioProfile.label)
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }
    Text {
        visible: Object.keys(section.controller.selectedSink).length > 0
        text: "Output         " + (section.controller.selectedSink.ready ? (section.controller.selectedSink.is_default ? "Ready · default" : "Ready") : "Not ready")
            + " · " + (section.controller.selectedSink.state || "unknown")
        color: section.controller.selectedSink.ready ? Ui.Theme.text : Ui.Theme.danger
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
    }
    Text {
        visible: Object.keys(section.controller.selectedSource).length > 0
        text: "Input          " + (section.controller.selectedSource.ready ? (section.controller.selectedSource.is_default ? "Ready · default" : "Ready") : "Not ready")
            + " · " + (section.controller.selectedSource.state || "unknown")
        color: section.controller.selectedSource.ready ? Ui.Theme.text : Ui.Theme.danger
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
    }
    Text {
        visible: section.controller.audioStatus.length > 0
        Layout.fillWidth: true
        text: section.controller.audioStatus
        color: Ui.Theme.danger
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
    }
    Text {
        visible: section.controller.selectedAudioProfiles.length > 0
        text: section.controller.selectedAudioProfiles.length + " audio profiles available"
        color: Ui.Theme.subtleText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: 11
    }
    Rectangle {
        visible: audioProfileList.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(126, audioProfileList.count * 31 + 2)
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceRaised
        border.color: Ui.Theme.border
        clip: true
        ListView {
            id: audioProfileList
            anchors.fill: parent
            anchors.margins: 1
            model: section.controller.selectedAudioProfiles
            delegate: Rectangle {
                id: audioProfileRow
                required property var modelData
                readonly property bool active: modelData.key === section.controller.selectedAudio.active_profile_key
                width: audioProfileList.width
                height: 31
                color: active ? Ui.Theme.selected : "transparent"
                opacity: modelData.available ? 1 : 0.45
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: (audioProfileRow.active ? "✓  " : "   ") + audioProfileRow.modelData.label
                    verticalAlignment: Text.AlignVCenter
                    color: audioProfileRow.active ? Ui.Theme.accent : Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: audioProfileRow.modelData.available && !audioProfileRow.active && !section.controller.actionInFlight
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: section.controller.setAudioProfile(audioProfileRow.modelData)
                }
            }
        }
    }
}
