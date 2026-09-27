import QtQuick

// Decorative values only: logical state, focus and hit geometry must not wait.
QtObject {
    id: motion

    property real target: 0
    property bool enabled: !Theme.noAnimations
    property real value: 0
    property bool ready: false

    onTargetChanged: value = target
    Component.onCompleted: {
        value = target;
        ready = true;
    }

    Behavior on value {
        enabled: motion.ready && motion.enabled
        // Disabling a Behavior alone does not stop an in-flight Qt spring.
        // Write only after this interceptor is disabled, not from the policy's
        // change handler, which can run before the enabled binding updates.
        onEnabledChanged: {
            if (!enabled)
                motion.value = motion.target;
        }
        SpringAnimation {
            spring: Theme.motionSpring
            damping: Theme.motionDamping
            epsilon: 0.01
        }
    }
}
