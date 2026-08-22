import QtQuick
import QtQuick.Controls as Controls

Controls.AbstractButton {
    id: option

    required property DropDownList owner
    required property int index
    required property var modelData
    readonly property bool selected: index === owner.currentIndex
    readonly property bool highlighted: owner.highlightedIndex === index
    readonly property string optionText: owner.optionText(modelData)

    width: owner.width
    height: Theme.compactControlHeight
    enabled: owner.optionEnabled(index)
    hoverEnabled: true
    leftPadding: Theme.spacingMd
    rightPadding: Theme.spacingMd

    contentItem: Text {
        text: option.optionText
        color: option.owner.delegateTextColor(option.highlighted)
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        font.weight: option.owner.delegateWeight(option.selected)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Theme.controlRadius
        color: option.owner.delegateBackground(
            option.highlighted, option.selected, option.hovered)
    }
}
