import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui

Item {
    id: root

    property string text
    property string tooltipText
    property color foreground: Ui.Theme.text
    property color hoverColor: Ui.Theme.hover
    property int horizontalPadding: 10
    property int minimumWidth: 0
    property bool interactive: true
    property alias elide: label.elide
    property alias fontWeight: label.font.weight
    property alias textHorizontalAlignment: label.horizontalAlignment

    signal primaryTriggered
    signal secondaryTriggered
    signal middleTriggered
    signal wheelUp
    signal wheelDown

    implicitWidth: Math.max(minimumWidth, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: 51

    Rectangle {
        anchors.fill: parent
        color: pointer.containsMouse && root.interactive ? root.hoverColor : "transparent"
    }

    Text {
        id: label
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        text: root.text
        color: root.foreground
        font.family: Ui.Theme.iconFontFamily
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                root.primaryTriggered();
            else if (mouse.button === Qt.RightButton)
                root.secondaryTriggered();
            else if (mouse.button === Qt.MiddleButton)
                root.middleTriggered();
        }
        onWheel: function (wheel) {
            if (wheel.angleDelta.y > 0)
                root.wheelUp();
            else if (wheel.angleDelta.y < 0)
                root.wheelDown();
        }
    }

    Controls.ToolTip.visible: pointer.containsMouse && tooltipText.length > 0
    Controls.ToolTip.text: tooltipText
    Controls.ToolTip.delay: 500
}
