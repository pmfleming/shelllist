import QtQuick
import QtQuick.Layouts
import "."
import Shelllist.Ui

Rectangle {
    id: content

    required property WifiController controller

    anchors.fill: parent
    radius: Theme.windowRadius
    color: Theme.window
    border.color: Theme.strongBorder
    border.width: 1

    function cancelPrompt() {
        if (controller.prompt.mode === "daemon-secret" && controller.prompt.secretRequestId.length > 0)
            controller.connection.cancelSecret(controller.prompt.secretRequestId);
        controller.prompt.cancel();
    }

    Shortcut {
        sequence: "F7"
        enabled: !content.controller.prompt.open && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("security")
    }

    Shortcut {
        sequence: "F8"
        enabled: !content.controller.prompt.open && !content.controller.advanced.open
        onActivated: content.controller.advanced.openSettings("hardware")
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection && !content.controller.prompt.open
        onActivated: content.controller.cycleDetailsTab()
    }

    Shortcut {
        sequence: "Left"
        enabled: content.controller.detailsOpen && !content.controller.advanced.open && !content.controller.prompt.open
        autoRepeat: false
        onActivated: content.controller.navigation.closeDetails()
    }

    Shortcut {
        sequence: "Escape"
        enabled: content.controller.prompt.open
        autoRepeat: false
        onActivated: content.cancelPrompt()
    }

    Shortcut {
        sequence: "Escape"
        enabled: content.controller.advanced.open && !content.controller.prompt.open
        autoRepeat: false
        onActivated: content.controller.advanced.closeSettings()
    }

    Shortcut {
        sequence: "Escape"
        enabled: !content.controller.prompt.open && !content.controller.advanced.open
        autoRepeat: false
        onActivated: content.controller.closeWindowRequested()
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(header.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(listPane.focusTop); }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: content.controller.contentMargin
        anchors.rightMargin: content.controller.contentMargin
        anchors.topMargin: content.controller.contentVerticalMargin
        anchors.bottomMargin: content.controller.contentVerticalMargin
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: content.controller.listPaneWidth
            Layout.maximumWidth: content.controller.listPaneWidth
            Layout.fillHeight: true
            spacing: 10

            WifiHeader {
                id: header
                filterText: content.controller.filterText
                onFilterEdited: function (text) {
                    content.controller.filterText = text;
                    content.controller.selectedIndex = 0;
                }
                onKeyPressed: function (event) { content.controller.navigation.handleSearchKey(event); }
                onRefreshRequested: content.controller.refresh()
            }

            NetworkListPane {
                id: listPane
                controller: content.controller
            }
        }

        Item {
            visible: content.controller.detailsRendered
            Layout.preferredWidth: content.controller.detailsPaneGapWidth
            Layout.minimumWidth: content.controller.detailsPaneGapWidth
            Layout.maximumWidth: content.controller.detailsPaneGapWidth
            Layout.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: 1
                height: parent.height
                color: Theme.border
                opacity: 0.75
            }
        }

        NetworkDetailsPane {
            controller: content.controller
            visible: content.controller.detailsRendered
            Layout.preferredWidth: content.controller.detailsPaneWidth
            Layout.minimumWidth: content.controller.detailsPaneWidth
            Layout.maximumWidth: content.controller.detailsPaneWidth
            Layout.fillHeight: true
        }
    }


    PromptDialog {
        visible: content.controller.prompt.open
        title: content.controller.prompt.title
        detail: content.controller.prompt.detail
        inputText: content.controller.prompt.text
        password: content.controller.prompt.password
        saveVisible: content.controller.prompt.mode === "daemon-secret" && content.controller.prompt.saveSecretSupported
        saveRequested: content.controller.prompt.saveSecret
        onInputEdited: function (text) { content.controller.prompt.text = text; }
        onSaveEdited: function (requested) { content.controller.prompt.saveSecret = requested; }
        onAccepted: content.controller.prompt.submit(content.controller)
        onCancelled: content.cancelPrompt()
    }
}
