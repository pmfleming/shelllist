import QtQuick

Behavior {
    property bool animate: true
    enabled: animate && !Theme.noAnimations
    NumberAnimation {
        duration: Theme.animationInteractive
        easing.type: Theme.easingResponsive
    }
}
