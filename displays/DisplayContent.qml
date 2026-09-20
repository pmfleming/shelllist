pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property DisplayController controller

    Ui.ChooserShortcuts {
        controller: content.controller
        navigationEnabled: !content.controller.discardPrompt && !content.controller.layoutDragging
        refreshEnabled: !content.controller.actionInFlight && !content.controller.trial && !content.controller.discardPrompt
        onRefreshRequested: content.controller.refresh()
    }
    Shortcut {
        sequence: "Ctrl+Return"
        enabled: content.controller.uiActive && content.controller.detailsOpen && content.controller.canPreview && !content.controller.discardPrompt
        autoRepeat: false
        onActivated: content.controller.preview()
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd
        enabled: !content.controller.trial && !content.controller.discardPrompt
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.headerHeight
            spacing: Ui.Theme.spacingMd
            Ui.FlatIconButton {
                Layout.preferredWidth: Ui.Theme.controlHeight
                Layout.preferredHeight: Ui.Theme.controlHeight
                icon: content.controller.detailsOpen ? "󰅁" : "󰍹"
                iconSize: Ui.Theme.iconSizeLarge
                flatIconColor: Ui.Theme.accent
                accessibleName: content.controller.detailsOpen ? qsTr("Back to displays") : qsTr("Identify displays")
                toolTip: accessibleName
                onClicked: content.controller.detailsOpen ? content.controller.closeDetails() : content.controller.identify()
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: qsTr("Displays")
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }
            Ui.ThemeText {
                text: content.controller.activeCount + " / " + content.controller.outputs.length
                color: Ui.Theme.mutedText
                Accessible.name: qsTr("%1 active of %2 connected displays").arg(content.controller.activeCount).arg(content.controller.outputs.length)
            }
            Ui.FlatIconButton {
                visible: content.controller.detailsOpen
                Layout.preferredWidth: Ui.Theme.controlHeight
                Layout.preferredHeight: Ui.Theme.controlHeight
                icon: "󰈈"
                accessibleName: qsTr("Identify displays")
                toolTip: accessibleName
                onClicked: content.controller.identify()
            }
        }
        Ui.ThemeText {
            objectName: "displayStatus"
            Layout.fillWidth: true
            visible: text.length > 0
            text: content.controller.statusMessage
            color: content.controller.displayPolicyError || content.controller.displayPolicyState.error ? Ui.Theme.danger : Ui.Theme.warning
            wrapMode: Text.Wrap
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: content.controller.detailsOpen ? workspace : overview
        }
        RowLayout {
            visible: content.controller.detailsOpen
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            Ui.GlyphLabel { glyph: content.controller.dirty ? "󰄱" : "󰄬"; color: content.controller.dirty ? Ui.Theme.warning : Ui.Theme.active }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: content.controller.dirty ? qsTr("Unsaved") : qsTr("Current")
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
            Ui.ActionButton {
                objectName: "reloadDisplayLayout"
                Layout.preferredWidth: Ui.Theme.controlHeight
                icon: "󰕍"
                accessibleName: content.controller.stale ? qsTr("Reload current displays") : qsTr("Discard layout changes")
                toolTip: accessibleName
                enabled: content.controller.canChange && (content.controller.dirty || content.controller.stale)
                onClicked: content.controller.reloadDraft()
            }
            Ui.ActionButton {
                objectName: "previewDisplayLayout"
                Layout.preferredWidth: 132
                label: qsTr("Preview")
                icon: "󰈈"
                tone: "accent"
                toolTip: qsTr("Ctrl+Enter · reverts after 20 seconds unless kept")
                enabled: content.controller.canPreview
                onClicked: content.controller.preview()
            }
        }
    }
    Component { id: overview; DisplayOverview { controller: content.controller } }
    Component { id: workspace; DisplayLayoutPane { controller: content.controller } }
    DisplayTrialDialog { controller: content.controller }
    Ui.PromptDialog {
        objectName: "discardDisplayDraft"
        visible: content.controller.discardPrompt
        title: qsTr("Discard layout changes?")
        inputVisible: false
        actionsVisible: true
        enterEnabled: false
        instruction: ""
        rejectLabel: qsTr("Keep editing")
        acceptLabel: qsTr("Discard")
        acceptTone: "warning"
        onAccepted: content.controller.discardAndClose()
        onCancelled: {
            content.controller.discardPrompt = false;
            content.controller.editorFocusRequested();
        }
    }
}
