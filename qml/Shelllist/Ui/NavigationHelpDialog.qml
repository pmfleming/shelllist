pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ModalFrame {
    id: dialog

    required property ChooserController controller
    property string surfaceName: "Shelllist"
    property bool helpEnabled: true
    property var entries: []

    readonly property var standardEntries: [
        { keys: "↑ / ↓", action: "Move selection" },
        { keys: "J / K", action: "Move selection while the list is focused" },
        { keys: "Enter", action: "Run the primary action" },
        { keys: "→ / ←", action: "Open / close details" },
        { keys: "Esc", action: "Close the current layer, then the chooser" },
        { keys: "? / F1", action: "Show / hide this shortcut guide" }
    ]
    readonly property var detailEntries: detailActionEntries()
    readonly property var allEntries: standardEntries.concat(entries || [], detailEntries)

    visible: controller.navigationHelpOpen
    z: 140
    title: surfaceName + " shortcuts"
    detail: "The same list and detail navigation works in every Shelllist chooser."
    maximumCardWidth: 620

    function detailActionEntries(): var {
        if (!controller.detailsOpen)
            return [];
        return (controller.detailActions || []).filter(function (action) {
            const shortcut = String(action.shortcut || "");
            return shortcut.length > 0 && shortcut.toLowerCase().indexOf("enter") < 0
                && action.visible !== false;
        }).map(function (action) {
            return {
                keys: action.shortcut,
                action: action.label + (action.enabled === false ? " (unavailable)" : "")
            };
        });
    }

    Shortcut {
        sequence: "?"
        enabled: dialog.helpEnabled
        onActivated: dialog.controller.toggleNavigationHelp()
    }
    Shortcut {
        sequence: "F1"
        enabled: dialog.helpEnabled
        onActivated: dialog.controller.toggleNavigationHelp()
    }
    Shortcut {
        sequence: "Escape"
        enabled: dialog.visible
        onActivated: dialog.controller.closeNavigationHelp()
    }

    ColumnLayout {
        width: parent.width
        spacing: Theme.spacingSm

        Flickable {
            id: shortcutView

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(shortcutColumn.implicitHeight,
                Math.max(180, dialog.height - 230))
            contentWidth: width
            contentHeight: shortcutColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Controls.ScrollBar.vertical: Controls.ScrollBar {}

            Column {
                id: shortcutColumn

                width: shortcutView.width
                spacing: Theme.spacingXs

                Repeater {
                    model: dialog.allEntries

                    delegate: Rectangle {
                        id: shortcutRow

                        required property var modelData

                        width: shortcutColumn.width
                        height: Theme.compactControlHeight
                        radius: Theme.controlRadius
                        color: index % 2 === 0 ? Theme.withAlpha(Theme.surfaceRaised, 0.72) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMd
                            anchors.rightMargin: Theme.spacingMd
                            spacing: Theme.spacingMd

                            Text {
                                Layout.preferredWidth: 126
                                text: shortcutRow.modelData.keys || ""
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                font.weight: Theme.fontWeightDemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: shortcutRow.modelData.action || ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeBody
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        ActionButton {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.controlHeight
            label: "Close"
            hotkey: "Esc"
            tone: "accent"
            onClicked: dialog.controller.closeNavigationHelp()
        }
    }
}
