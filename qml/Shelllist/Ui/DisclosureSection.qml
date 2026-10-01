pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Presentation only: keep children/drafts alive while hiding secondary content.
Column {
    id: section
    property string title: ""
    property bool expanded: false
    property bool attention: false
    readonly property bool open: expanded || attention
    default property alias content: body.data
    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingSm

    ActionControl {
        id: disclosure
        objectName: section.objectName ? section.objectName + "Toggle" : ""
        width: parent.width
        implicitHeight: Math.max(56, disclosureLabel.implicitHeight + 2 * Theme.spacingLg)
        radius: Theme.panelRadius
        color: disclosurePointer.pressed ? Theme.surfaceContainer : Theme.surface
        border.width: 0
        accessibleName: section.title
        Accessible.description: section.attention ? qsTr("Attention required") : section.open ? qsTr("Expanded") : qsTr("Collapsed")
        interactive: !section.attention
        onClicked: section.expanded = !section.expanded
        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd
            ThemeText {
                id: disclosureLabel
                Layout.fillWidth: true
                text: section.title
                font.pixelSize: Theme.fontSizeHeading
                wrapMode: Text.WordWrap
            }
            GlyphLabel {
                glyph: section.open ? "expand_less" : "expand_more"
                font.pixelSize: Theme.iconSizeLarge
                color: Theme.mutedText
            }
        }
        ControlPointerArea {
            id: disclosurePointer
            focusTarget: disclosure
            enabled: disclosure.enabled && disclosure.interactive
            onClicked: disclosure.activate()
        }
    }
    ColumnLayout {
        id: body
        width: parent.width
        visible: section.open
        spacing: Theme.spacingMd
    }
}
