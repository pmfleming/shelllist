import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: content

    required property var controller

    anchors.fill: parent
    radius: Theme.windowRadius
    color: Theme.window
    border.color: Theme.strongBorder
    border.width: 1

    Shortcut {
        sequence: "F7"
        enabled: !content.controller.prompt.open && !content.controller.advancedOpen
        onActivated: content.controller.openAdvancedSettings("security")
    }

    Shortcut {
        sequence: "F8"
        enabled: !content.controller.prompt.open && !content.controller.advancedOpen
        onActivated: content.controller.openAdvancedSettings("hardware")
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection && !content.controller.prompt.open
        onActivated: content.controller.cycleDetailsTab()
    }

    Shortcut {
        sequence: "Escape"
        enabled: content.controller.advancedOpen && !content.controller.prompt.open
        onActivated: content.controller.closeAdvancedSettings()
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(header.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(listPane.focusTop); }
    }

    RowLayout {
        id: mainContent

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
        onCancelled: {
            if (content.controller.prompt.mode === "daemon-secret" && content.controller.prompt.secretRequestId.length > 0)
                content.controller.cancelSecret(content.controller.prompt.secretRequestId);
            content.controller.prompt.cancel();
        }
    }
}
