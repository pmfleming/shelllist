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

    Component.onCompleted: {
        controller.activeHeader = header;
        controller.activeListPane = listPane;
    }

    Component.onDestruction: {
        if (controller.activeHeader === header)
            controller.activeHeader = null;
        if (controller.activeListPane === listPane)
            controller.activeListPane = null;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: 425
            Layout.maximumWidth: 425
            Layout.fillHeight: true
            spacing: 12

            WifiHeader {
                id: header
                filterText: controller.filterText
                onFilterEdited: function (text) {
                    controller.filterText = text;
                    controller.selectedIndex = 0;
                }
                onKeyPressed: function (event) { controller.handleSearchKey(event); }
                onRefreshRequested: controller.refresh()
            }

            NetworkListPane {
                id: listPane
                controller: content.controller
            }
        }

        Item {
            visible: controller.detailsRendered
            Layout.preferredWidth: controller.detailsPaneGapWidth
            Layout.minimumWidth: controller.detailsPaneGapWidth
            Layout.maximumWidth: controller.detailsPaneGapWidth
            Layout.fillHeight: true
        }

        NetworkDetailsPane {
            controller: content.controller
            visible: controller.detailsRendered
            Layout.preferredWidth: controller.detailsPaneWidth
            Layout.minimumWidth: controller.detailsPaneWidth
            Layout.maximumWidth: controller.detailsPaneWidth
            Layout.fillHeight: true
        }
    }

    PromptDialog {
        visible: controller.prompt.open
        title: controller.prompt.title
        detail: controller.prompt.detail
        inputText: controller.prompt.text
        password: controller.prompt.password
        onInputEdited: function (text) { controller.prompt.text = text; }
        onAccepted: controller.prompt.submit(controller)
        onCancelled: controller.prompt.cancel()
    }
}
