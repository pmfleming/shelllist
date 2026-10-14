// SPDX-License-Identifier: GPL-3.0-or-later
// Opaque scanner actions: camera/image pixels must never determine contrast.
import QtQuick
import QtQuick.Controls.Basic as Controls

Controls.Button {
    id: control
    readonly property color foregroundColor: enabled ? "#ffffff" : "#bdc1c6"
    readonly property color surfaceColor: !enabled ? "#3c4043" : down ? "#45464a" : checked ? "#345077" : hovered ? "#35363a" : "#202124"
    readonly property color outlineColor: visualFocus ? "#a8c7fa" : "#9aa0a6"

    implicitHeight: Math.max(44, implicitContentHeight + topPadding + bottomPadding)
    padding: 12
    opacity: 1
    icon.color: foregroundColor
    palette.buttonText: foregroundColor
    palette.brightText: foregroundColor
    palette.highlightedText: foregroundColor
    palette.windowText: foregroundColor
    palette.text: foregroundColor
    palette.disabled.buttonText: foregroundColor
    palette.disabled.brightText: foregroundColor
    palette.disabled.windowText: foregroundColor

    background: Rectangle {
        color: control.surfaceColor
        radius: 6
        border.width: control.visualFocus ? 2 : 1
        border.color: control.outlineColor
    }
}
