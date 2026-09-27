import QtQuick
import QtQuick.Layouts

RowLayout {
    id: layout

    required property ChooserController controller
    required property Component listComponent
    required property Component detailsComponent
    property bool keyboardWorkflow: false
    readonly property alias detailsNavigation: detailsNavigation
    readonly property ChooserListPane listItem: listLoader.item as ChooserListPane
    readonly property Item detailsItem: detailsLoader.item as Item
    readonly property real verticalDensity: Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property int verticalMargin: Theme.verticalSpacing(controller.contentVerticalMargin, verticalDensity)

    function focusSearch() {
        if (listItem)
            listItem.focusSearch();
    }
    function focusList() {
        if (listItem)
            listItem.focusList();
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
        function onUiActiveChanged() {
            if (!layout.controller.uiActive)
                detailsNavigation.suspendView();
        }
        function onFocusSearchRequested() {
            Qt.callLater(layout.focusSearch);
        }
        function onFocusListTopRequested() {
            layout.focusTop();
        }
        function onFocusDetailsRequested() {
            if (layout.keyboardWorkflow)
                detailsNavigation.focusRememberedContent();
        }
        function onSearchTextRequested(text: string) {
            if (layout.listItem)
                layout.listItem.insertSearchText(text);
        }
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

    DetailsNavigation {
        id: detailsNavigation
        contentItem: layout.keyboardWorkflow ? layout.detailsItem : null
        viewMemory: layout.keyboardWorkflow ? layout.controller.viewMemory : null
        onResultContextChanged: layout.focusList()
        onExitRequested: {
            layout.controller.closeDetails();
            layout.focusList();
        }
        visible: layout.controller.detailsRendered
        enabled: layout.controller.detailsOpen
        Layout.preferredWidth: layout.controller.detailsPaneWidth
        Layout.minimumWidth: layout.controller.detailsPaneWidth
        Layout.maximumWidth: layout.controller.detailsPaneWidth
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
