import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: bullet

    required property string label
    required property string valueText
    required property real value
    required property real maximum
    required property color accentColor
    property real peak: 0
    property bool available: true
    property real uiScale: 1

    height: Math.round(68 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(10 * bullet.uiScale)
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: bullet.label
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Text {
                text: bullet.valueText
                color: bullet.available ? bullet.accentColor : Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightBold
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Ui.Theme.input
                border.color: Ui.Theme.border
                border.width: 1
            }
            Rectangle {
                visible: bullet.available
                x: 1
                y: 1
                height: parent.height - 2
                width: Math.max(0, (parent.width - 2)
                    * Math.min(1, Math.max(0, bullet.value) / Math.max(1, bullet.maximum)))
                radius: height / 2
                color: Ui.Theme.withAlpha(bullet.accentColor, 0.78)
            }
            Rectangle {
                visible: bullet.available && bullet.peak > 0
                x: Math.max(1, Math.min(parent.width - width - 1,
                    (parent.width - 2) * bullet.peak / Math.max(1, bullet.maximum)))
                y: 0
                width: 2
                height: parent.height
                color: Ui.Theme.text
            }
            Canvas {
                anchors.fill: parent
                visible: !bullet.available
                onPaint: {
                    const context = getContext("2d");
                    context.reset();
                    context.beginPath();
                    for (let x = -height; x < width + height; x += 7) {
                        context.moveTo(x, height);
                        context.lineTo(x + height, 0);
                    }
                    context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.28);
                    context.lineWidth = 1;
                    context.stroke();
                }
            }
        }
    }
}
