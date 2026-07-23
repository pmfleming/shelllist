import QtQuick
import QtQuick.Layouts

RowLayout {
    id: layout

    required property var controller
    property Component listComponent
    property Component detailsComponent
    readonly property var listItem: listLoader.item
    readonly property var detailsItem: detailsLoader.item

    anchors.fill: parent
    anchors.leftMargin: controller.contentMargin
    anchors.rightMargin: controller.contentMargin
    anchors.topMargin: controller.contentVerticalMargin
    anchors.bottomMargin: controller.contentVerticalMargin
    spacing: 0

    Loader {
        id: listLoader

        Layout.preferredWidth: layout.controller.listPaneWidth
        Layout.minimumWidth: layout.controller.listPaneWidth
        Layout.maximumWidth: layout.controller.listPaneWidth
        Layout.fillHeight: true
        sourceComponent: layout.listComponent
    }

    Item {
        visible: layout.controller.detailsRendered
        Layout.preferredWidth: layout.controller.detailsPaneGapWidth
        Layout.minimumWidth: layout.controller.detailsPaneGapWidth
        Layout.maximumWidth: layout.controller.detailsPaneGapWidth
        Layout.fillHeight: true

        VerticalDivider {}
    }

    Loader {
        id: detailsLoader

        visible: layout.controller.detailsRendered
        Layout.preferredWidth: layout.controller.detailsPaneWidth
        Layout.minimumWidth: layout.controller.detailsPaneWidth
        Layout.maximumWidth: layout.controller.detailsPaneWidth
        Layout.fillHeight: true
        sourceComponent: layout.detailsComponent
    }
}
