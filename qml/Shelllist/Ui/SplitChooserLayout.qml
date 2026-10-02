import QtQuick

// These panes have explicit animated widths. A RowLayout can redistribute
// transient rounding slack and move the fixed list by a pixel mid-animation.
// Anchor the list and place the expanding panes directly instead.
Item {
    id: layout

    required property ChooserController controller
    required property Component listComponent
    required property Component detailsComponent
    property bool keyboardWorkflow: false
    property bool navigationAllowed: true
    property string sessionContext: ""
    property bool sessionReady: true
    readonly property alias detailsNavigation: detailsNavigation
    readonly property ChooserListPane listItem: listLoader.item as ChooserListPane
    readonly property Item detailsItem: detailsLoader.item as Item
    readonly property real verticalDensity: Theme.densityScale(height, controller.contentVerticalMargin)
    readonly property int verticalMargin: Theme.verticalSpacing(controller.contentVerticalMargin, verticalDensity)

    function focusSearch(generation: int): void {
        if (generation !== controller.uiGeneration || !controller.uiActive || controller.uiSuspending || !navigationAllowed)
            return;
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

    Connections {
        target: layout.controller
        function onUiActiveChanged() {
            if (!layout.controller.uiActive)
                detailsNavigation.suspendView();
        }
        function onFocusSearchRequested() {
            session.cancel();
            Qt.callLater(layout.focusSearch, layout.controller.uiGeneration);
        }
        function onFocusListTopRequested() {
            session.cancel();
            layout.focusTop();
        }
        function onFocusDetailsRequested() {
            session.cancel();
            if (layout.keyboardWorkflow)
                detailsNavigation.focusRememberedContent();
        }
        function onSearchTextRequested(text: string) {
            session.cancel();
            if (layout.listItem)
                layout.listItem.insertSearchText(text);
        }
    }

    ChooserSession {
        id: session
        enabled: layout.keyboardWorkflow && layout.controller.viewMemory !== null
        controller: layout.controller
        listItem: layout.listItem
        navigation: detailsNavigation
        navigationAllowed: layout.navigationAllowed
        context: layout.sessionContext
        ready: layout.sessionReady
    }

    Loader {
        id: listLoader

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: layout.controller.listPaneWidth
        active: true
        sourceComponent: layout.listComponent
    }

    Item {
        id: detailsGap
        visible: layout.controller.detailsRendered
        anchors.left: listLoader.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: layout.controller.detailsPaneGapWidth

        VerticalDivider {}
    }

    DetailsNavigation {
        id: detailsNavigation
        contentItem: layout.keyboardWorkflow ? layout.detailsItem : null
        viewMemory: layout.keyboardWorkflow ? layout.controller.viewMemory : null
        restorationAllowed: layout.controller.uiActive && !layout.controller.uiSuspending && layout.navigationAllowed
        onResultContextChanged: layout.focusList()
        onExitRequested: {
            layout.controller.closeDetails();
            if (!layout.controller.detailsOpen && layout.navigationAllowed)
                layout.focusList();
        }
        visible: layout.controller.detailsRendered
        enabled: layout.controller.detailsOpen
        anchors.left: detailsGap.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: layout.controller.detailsPaneWidth
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
