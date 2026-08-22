pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property string surfaceName: "Shelllist"
    property var helpEntries: []
    property bool navigationEnabled: true
    property bool refreshEnabled: true
    property bool detailsTabEnabled: false
    property bool refreshAutoRepeat: true
    property bool helpEnabled: chooserController.uiActive
    readonly property real uiScale: Theme.densityScale(height,
        chooserController.contentVerticalMargin)
    readonly property var listItem: chooser.listItem
    readonly property var detailsItem: chooser.detailsItem

    signal refreshRequested
    signal detailsTabRequested

    ChooserShortcuts {
        controller: surface.chooserController
        navigationEnabled: surface.navigationEnabled
        refreshEnabled: surface.refreshEnabled
        detailsTabEnabled: surface.detailsTabEnabled
        refreshAutoRepeat: surface.refreshAutoRepeat
        onRefreshRequested: surface.refreshRequested()
        onDetailsTabRequested: surface.detailsTabRequested()
    }

    SplitChooserLayout {
        id: chooser
        controller: surface.chooserController
        listComponent: surface.listComponent
        detailsComponent: surface.detailsComponent
    }

    NavigationHelpDialog {
        controller: surface.chooserController
        surfaceName: surface.surfaceName
        helpEnabled: surface.helpEnabled
        entries: surface.helpEntries
    }
}
