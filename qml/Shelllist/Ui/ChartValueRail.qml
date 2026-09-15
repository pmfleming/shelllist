pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: rail
    required property string label
    required property string valueText
    required property string referenceText
    property color valueColor: Theme.accent
    implicitHeight: 39 + reference.implicitHeight

    ThemeText {
        y: 4
        width: parent.width
        text: rail.label
        color: Theme.mutedText
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeCaption
        font.weight: Theme.fontWeightDemiBold
    }
    ThemeText {
        objectName: "chartValue"
        y: 20
        width: parent.width
        text: rail.valueText
        color: rail.valueColor
        elide: Text.ElideRight
        font.weight: Theme.fontWeightBold
    }
    ThemeText {
        id: reference
        y: 39
        width: parent.width
        text: rail.referenceText
        color: Theme.subtleText
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeCaption
    }
}
