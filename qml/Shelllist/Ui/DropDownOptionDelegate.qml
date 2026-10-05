import QtQuick
import QtQuick.Controls as Controls

Controls.AbstractButton {
    id: option

    required property DropDownList owner
    required property int index
    required property var modelData
    readonly property bool selected: index === owner.selectedIndex
    readonly property bool highlighted: owner.highlightedIndex === index
    readonly property string optionText: owner.optionText(modelData)
    readonly property color foreground: highlighted ? Theme.accentText : (selected ? Theme.selectedText : Theme.text)

    objectName: "dropDownOption-" + index
    width: Math.max(0, owner.popup.availableWidth)
    height: Theme.formCompactHeight
    enabled: owner.enabled && owner.interactive && owner.optionEnabled(index)
    opacity: enabled ? 1 : Theme.disabledOpacity
    // ComboBox treats AbstractButton.hovered as keyboard highlighting. Observe
    // hover separately so merely passing the pointer cannot redirect Enter.
    hoverEnabled: false
    leftPadding: Theme.formPadding
    rightPadding: Theme.formPadding
    Accessible.role: Accessible.ListItem
    Accessible.name: optionText
    Accessible.selected: selected

    HoverHandler {
        id: hover
        enabled: option.enabled
    }
    contentItem: ThemeText {
        text: option.optionText
        color: option.foreground
        font.pixelSize: Theme.formValueSize
        font.weight: option.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: 8
        color: option.highlighted ? Theme.accent : (option.selected ? Theme.selected : Theme.surfaceRaised)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: option.foreground
            opacity: option.down ? 0.12 : (hover.hovered ? 0.08 : 0)
        }
    }
    FocusRing {
        active: option.owner.popup.visible && option.highlighted && option.enabled
        cornerRadius: 8
        ringColor: option.foreground
    }
}
