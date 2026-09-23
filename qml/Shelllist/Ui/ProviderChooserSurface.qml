pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property string surfaceName: "Shelllist"
    property alias minimumSplitDetailsWidth: chooser.minimumSplitDetailsWidth
    property var helpEntries: []
    property bool navigationEnabled: !chooserController.navigationHelpOpen
    property bool refreshEnabled: navigationEnabled && !chooserController.actionInFlight
    property bool detailsTabEnabled: navigationEnabled && chooserController.detailsOpen && chooserController.hasSelection
    property bool refreshAutoRepeat: true
    property bool helpEnabled: chooserController.uiActive
    readonly property real uiScale: Theme.densityScale(height, chooserController.contentVerticalMargin)
    readonly property ChooserListPane listItem: chooser.listItem
    readonly property Item detailsItem: chooser.detailsItem

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
