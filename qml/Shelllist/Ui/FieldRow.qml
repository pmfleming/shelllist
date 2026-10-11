pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Passive composition shared by every setting family. Native controls keep
// their identities, edit sessions and acknowledgement owners.
Item {
    id: row
    default property alias content: editorHost.data
    property alias accessories: accessoryHost.data
    property bool accessoriesVisible: true
    readonly property Item controlItem: editorHost.children.find(child => child !== editorSpacer) || null
    property string label: ""
    property string labelObjectName: "fieldRowLabel"
    property var icons: []
    property string subtitle: ""
    property color labelColor: Theme.mutedText
    property color subtitleColor: Theme.mutedText
    property bool separatorVisible: true
    // Fixed-size editors (switches) leave the remaining width to their labels.
    property bool fixedEditorWidth: false
    readonly property real labelColumnWidth: labelHost.width
    readonly property real editorX: editorHost.x

    implicitWidth: 320
    implicitHeight: Math.max(Theme.formHeight, labels.implicitHeight + 2 * Theme.spacingSm, editorHost.implicitHeight, accessoryHost.implicitHeight)
    Layout.minimumWidth: 0
    Layout.fillWidth: true

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingMd
        RowLayout {
            id: labelHost
            visible: row.label.length > 0 || row.icons.length > 0
            Layout.fillWidth: row.fixedEditorWidth
            Layout.preferredWidth: row.fixedEditorWidth ? 1 : Theme.fieldLabelWidth(row.width)
            Layout.minimumWidth: row.fixedEditorWidth ? 0 : Theme.fieldLabelWidth(row.width)
            Layout.maximumWidth: row.fixedEditorWidth ? Number.POSITIVE_INFINITY : Theme.fieldLabelWidth(row.width)
            spacing: Theme.spacingSm
            Repeater {
                model: row.icons
                delegate: GlyphLabel {
                    required property string modelData
                    objectName: "fieldRowIcon"
                    glyph: modelData
                    Layout.preferredWidth: Theme.formIconSize
                    font.pixelSize: Theme.formIconSize
                    Accessible.ignored: true
                }
            }
            Column {
                id: labels
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: Theme.spacingXs
                ThemeText {
                    objectName: row.labelObjectName
                    width: parent.width
                    text: row.label
                    color: row.labelColor
                    font.pixelSize: Theme.fieldNameSize
                    font.weight: Theme.fieldNameWeight
                    wrapMode: Text.Wrap
                    Accessible.ignored: true
                }
                ThemeText {
                    objectName: "fieldRowSubtitle"
                    width: parent.width
                    visible: text.length > 0
                    text: row.subtitle
                    color: row.subtitleColor
                    font.pixelSize: Theme.metadataSize
                    wrapMode: Text.Wrap
                    Accessible.ignored: true
                }
            }
        }
        RowLayout {
            id: editorHost
            objectName: "fieldRowEditorHost"
            Layout.fillWidth: !row.fixedEditorWidth
            Layout.minimumWidth: row.fixedEditorWidth ? implicitWidth : 0
            Layout.maximumWidth: row.width
            Layout.preferredWidth: row.fixedEditorWidth ? implicitWidth : 1
            spacing: Theme.spacingSm
            Item {
                id: editorSpacer
                Layout.fillWidth: true
                visible: !row.fixedEditorWidth && row.controlItem !== null && !row.controlItem.Layout.fillWidth
            }
        }
        RowLayout {
            id: accessoryHost
            visible: row.accessoriesVisible && children.length > 0
            spacing: Theme.spacingSm
        }
    }
    Rectangle {
        objectName: "fieldRowSeparator"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        visible: row.separatorVisible
        color: Theme.border
        Accessible.ignored: true
    }
}
