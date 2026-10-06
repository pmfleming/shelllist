import QtQuick
import QtQuick.Controls as Controls

Controls.AbstractButton {
    id: option

    required property DropDownList owner
    required property int index
    required property var modelData
    // A saved check is acknowledgement, never the field-local choice draft.
    readonly property bool selected: index === owner.acknowledgedIndex
    readonly property string optionIcon: String(modelData.icon || "")
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
    onClicked: owner.acceptOptionClick(index)

    HoverHandler {
        id: hover
        enabled: option.enabled
    }
    contentItem: ThemeText {
        text: option.optionText
        leftPadding: option.optionIcon ? Theme.formIconSize + Theme.spacingSm : 0
        rightPadding: Theme.formIconSize + Theme.spacingSm
        color: option.foreground
        font.pixelSize: Theme.formValueSize
        font.weight: option.selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        GlyphLabel {
            objectName: "dropDownOptionIcon"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: option.optionIcon.length > 0
            glyph: option.optionIcon
            font.pixelSize: Theme.formIconSize
            color: option.foreground
            Accessible.ignored: true
        }
        GlyphLabel {
            objectName: "dropDownSelectedCheck"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: option.selected
            glyph: "check"
            font.pixelSize: Theme.formIconSize
            color: option.foreground
            Accessible.ignored: true
        }
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
