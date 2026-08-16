import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui

Item {
    id: root

    required property string text
    required property string tooltipText
    property color foreground: Ui.Theme.text
    property color hoverColor: Ui.Theme.hover
    property int horizontalPadding: 10
    property int minimumWidth: 0
    property bool interactive: true
    property alias elide: label.elide
    property alias fontWeight: label.font.weight

    signal primaryTriggered
    signal secondaryTriggered
    signal middleTriggered
    signal wheelUp
    signal wheelDown

    function routeClick(button: int): void {
        if (!interactive)
            return;
        const handlers = ({});
        handlers[Qt.LeftButton] = primaryTriggered;
        handlers[Qt.RightButton] = secondaryTriggered;
        handlers[Qt.MiddleButton] = middleTriggered;
        if (handlers[button])
            handlers[button]();
    }

    function routeWheel(delta: int): void {
        if (!interactive || delta === 0)
            return;
        (delta > 0 ? wheelUp : wheelDown)();
    }

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
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function (mouse) { root.routeClick(mouse.button); }
        onWheel: function (wheel) { root.routeWheel(wheel.angleDelta.y); }
    }

    Controls.ToolTip.visible: pointer.containsMouse && tooltipText.length > 0
    Controls.ToolTip.text: tooltipText
    Controls.ToolTip.delay: 500
}
