import QtQuick
import QtQuick.Layouts

RowLayout {
    id: layout

    required property ChooserController controller
    required property Component listComponent
    required property Component detailsComponent
    // Opt in for surfaces that must fit small outputs without clipping details.
    property real minimumSplitDetailsWidth: 0
    readonly property bool singlePane: minimumSplitDetailsWidth > 0 && width < controller.listPaneWidth + controller.detailsGapWidth + minimumSplitDetailsWidth
    readonly property real listWidth: singlePane ? width : controller.listPaneWidth
    readonly property real detailWidth: singlePane ? width : controller.detailsPaneWidth
    readonly property var listItem: listLoader.item
    readonly property var detailsItem: detailsLoader.item
    readonly property real verticalDensity: Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property int verticalMargin: Theme.verticalSpacing(controller.contentVerticalMargin, verticalDensity)

    function focusSearch() {
        if (listItem)
            listItem.focusSearch();
    }
    function focusTop() {
        if (listItem)
            listItem.focusTop();
    }

    anchors.fill: parent
    anchors.leftMargin: controller.contentMargin
    anchors.rightMargin: controller.contentMargin
    anchors.topMargin: layout.verticalMargin
    anchors.bottomMargin: layout.verticalMargin
    spacing: 0

    Connections {
        target: layout.controller
        function onFocusSearchRequested() {
            Qt.callLater(layout.focusSearch);
        }
        function onFocusListTopRequested() {
            Qt.callLater(layout.focusTop);
        }
    }

    Loader {
        id: listLoader

        visible: !layout.singlePane || !layout.controller.detailsRendered
        Layout.preferredWidth: layout.listWidth
        Layout.minimumWidth: layout.listWidth
        Layout.maximumWidth: layout.listWidth
        Layout.fillHeight: true
        active: true
        sourceComponent: layout.listComponent
    }

    Item {
        visible: layout.controller.detailsRendered && !layout.singlePane
        Layout.preferredWidth: layout.controller.detailsPaneGapWidth
        Layout.minimumWidth: layout.controller.detailsPaneGapWidth
        Layout.maximumWidth: layout.controller.detailsPaneGapWidth
        Layout.fillHeight: true

        VerticalDivider {}
    }

    Item {
        visible: layout.controller.detailsRendered
        Layout.preferredWidth: layout.detailWidth
        Layout.minimumWidth: layout.detailWidth
        Layout.maximumWidth: layout.detailWidth
        Layout.fillHeight: true
        clip: true

        PulsingLabel {
            anchors.centerIn: parent
            visible: detailsLoader.status === Loader.Loading
            text: qsTr("Loading details…")
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeBody
        }

        Loader {
            id: detailsLoader

            anchors.fill: parent
            active: layout.controller.detailsRendered
            asynchronous: true
            sourceComponent: layout.detailsComponent
        }
    }
}
