import QtQuick
import QtQuick.Layouts

RowLayout {
    id: layout

    required property ChooserController controller
    property Component listComponent
    property Component detailsComponent
    readonly property var listItem: listLoader.item
    readonly property var detailsItem: detailsLoader.item

    function focusSearch() { if (listItem) listItem.focusSearch(); }
    function focusTop() { if (listItem) listItem.focusTop(); }

    anchors.fill: parent
    anchors.leftMargin: controller.contentMargin
    anchors.rightMargin: controller.contentMargin
    anchors.topMargin: controller.contentVerticalMargin
    anchors.bottomMargin: controller.contentVerticalMargin
    spacing: 0

    Connections {
        target: layout.controller
        function onFocusSearchRequested() { Qt.callLater(layout.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(layout.focusTop); }
    }

    Loader {
        id: listLoader

        Layout.preferredWidth: layout.controller.listPaneWidth
        Layout.minimumWidth: layout.controller.listPaneWidth
        Layout.maximumWidth: layout.controller.listPaneWidth
        Layout.fillHeight: true
        active: true
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
        active: layout.controller.detailsRendered
        sourceComponent: layout.detailsComponent
    }
}
