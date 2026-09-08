pragma ComponentBehavior: Bound

import QtQuick

Flow {
    id: list

    required property var actions
    property int minimumButtonWidth: 74
    property int maximumButtonWidth: 150
    property real characterWidth: 8
    property int horizontalPadding: 24
    property int controlHeight: 34
    signal triggered(string actionKey)

    visible: actions.length > 0
    spacing: Theme.spacingSm

    FontMetrics {
        id: actionFont
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
    }

    Repeater {
        model: list.actions
        ActionButton {
            required property var modelData
            readonly property string fullLabel: String(modelData.label || qsTr("Action"))
            objectName: "notificationAction-" + modelData.key
            width: Math.max(0, Math.min(list.width, Math.max(list.minimumButtonWidth, Math.min(list.maximumButtonWidth, fullLabel.length * list.characterWidth + list.horizontalPadding))))
            height: list.controlHeight
            label: actionFont.elidedText(fullLabel, Qt.ElideRight, Math.max(0, width - 20))
            accessibleName: fullLabel
            toolTip: fullLabel
            onClicked: list.triggered(modelData.key)
        }
    }
}
