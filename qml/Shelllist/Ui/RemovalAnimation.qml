import QtQuick

SequentialAnimation {
    id: removal

    required property Item targetItem
    required property bool removalRequested
    required property var finishRemoval

    running: removalRequested

    ParallelAnimation {
        NumberAnimation {
            target: removal.targetItem
            property: "opacity"
            to: 0
            duration: Theme.noAnimations ? 0 : Theme.animationFast
        }
        NumberAnimation {
            target: removal.targetItem
            property: "scale"
            to: 0.96
            duration: Theme.noAnimations ? 0 : Theme.animationFast
        }
    }
    ScriptAction {
        script: if (removal.finishRemoval) removal.finishRemoval()
    }
}
