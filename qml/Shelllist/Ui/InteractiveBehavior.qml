import QtQuick

// Shared decorative interpolation for numeric and color properties. Logical
// state and focus still update immediately; springs use ExpressiveMotion.
Behavior {
    id: behavior
    property bool animate: true
    property int duration: Theme.animationInteractive
    property int easingType: Theme.easingResponsive
    enabled: animate && !Theme.noAnimations
    PropertyAnimation {
        duration: behavior.duration
        easing.type: behavior.easingType
    }
}
