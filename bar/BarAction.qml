import QtQuick
import Shelllist.Ui as Ui

Ui.ActionControl {
    id: root

    required property string text
    property color foreground: Ui.Theme.text
    property color backgroundColor: "transparent"
    property color borderColor: "transparent"
    property bool symbolic: true
    activeFocusOnTab: false
    radius: height / 2
    property int horizontalPadding: 10
    property int minimumWidth: 0
    accessibleName: text
    onClicked: primaryTriggered()
    property alias elide: label.elide
    property alias fontWeight: label.font.weight

    signal primaryTriggered
    signal secondaryTriggered
    signal middleTriggered
    signal wheelUp
    signal wheelDown

    function routeClick(button: int): void {
        if (!enabled || !interactive)
            return;
        const handlers = ({});
        handlers[Qt.LeftButton] = activate;
        handlers[Qt.RightButton] = secondaryTriggered;
        handlers[Qt.MiddleButton] = middleTriggered;
        if (handlers[button])
            handlers[button]();
    }

    function routeWheel(delta: int): void {
        if (!enabled || !interactive || delta === 0)
            return;
        (delta > 0 ? wheelUp : wheelDown)();
    }

    implicitWidth: Math.max(minimumWidth, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: 37

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.backgroundColor
        border.width: 1
        border.color: root.borderColor

        Ui.InteractiveBehavior on color {
            duration: Ui.Theme.animationFast
            easingType: Easing.Linear
        }
    }

    Ui.GlyphLabel {
        id: label
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        glyph: root.text
        color: root.foreground
        font.family: root.symbolic ? (symbol ? Ui.Theme.symbolFontFamily : Ui.Theme.iconFontFamily) : Ui.Theme.fontFamily
        font.pixelSize: root.symbolic ? 20 : Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone

        Ui.InteractiveBehavior on color {
            duration: Ui.Theme.animationFast
            easingType: Easing.Linear
        }
    }

    Ui.StateLayer {
        focusTarget: root
        radius: height / 2
        stateColor: root.foreground
        showStateBackground: true
        hoverOpacity: 0.09
        pressedOpacity: 0.15
        interactive: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        consumeWheel: false
        onClicked: function (mouse) {
            root.routeClick(mouse.button);
        }
        onWheel: function (event) {
            root.routeWheel(event.angleDelta.y);
        }
    }
}
