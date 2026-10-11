import QtQuick
import QtQuick.Layouts

PointerActionControl {
    id: row
    property string title: ""
    property string subtitle: ""
    property string hotkey: ""
    property string tone: "normal"
    property bool checked: false
    property bool showSubtitle: true
    property bool wrapTitle: true
    property bool compact: false
    property var icons: []
    width: parent ? parent.width : 0
    implicitHeight: layout.implicitHeight
    Layout.minimumHeight: implicitHeight
    radius: Theme.controlRadius
    color: "transparent"
    focusSurface: toggleFocus
    border.width: 0
    accessibleName: subtitle.length ? title + ". " + subtitle : title
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    Accessible.onToggleAction: activate()

    FieldRow {
        id: layout
        anchors.fill: parent
        label: row.title
        fixedEditorWidth: true
        icons: row.icons
        subtitle: row.showSubtitle ? row.subtitle : ""
        labelColor: row.tone === "danger" ? Theme.danger : row.tone === "active" ? Theme.active : row.tone === "warning" ? Theme.warning : Theme.mutedText
        Rectangle {
            id: toggleFocus
            Layout.preferredWidth: 64
            Layout.minimumWidth: 64
            Layout.preferredHeight: Theme.controlHeight
            radius: height / 2
            color: row.pointerPressed ? Theme.pressed : row.hovered ? Theme.hover : "transparent"
            TogglePill {
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                opacity: row.enabled && row.interactive ? 1.0 : Theme.disabledOpacity
                checked: row.checked
                pressed: row.pressed
                checkedColor: row.tone === "danger" ? Theme.danger : row.tone === "active" ? Theme.active : row.tone === "warning" ? Theme.warning : Theme.accent
                handleColor: !checked ? Theme.controlBorder : row.tone === "danger" ? Theme.dangerText : row.tone === "active" ? Theme.activeText : row.tone === "warning" ? Theme.warningText : Theme.accentText
            }
        }
    }
}
