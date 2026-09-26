pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property alias minimumSplitDetailsWidth: chooser.minimumSplitDetailsWidth
    property bool navigationEnabled: true
    property bool refreshEnabled: navigationEnabled && !chooserController.actionInFlight
    property bool detailsTabEnabled: navigationEnabled && chooserController.detailsOpen && chooserController.hasSelection
    property bool refreshAutoRepeat: true
    readonly property real uiScale: Theme.densityScale(height, chooserController.contentVerticalMargin)
    readonly property ChooserListPane listItem: chooser.listItem
    readonly property Item detailsItem: chooser.detailsItem

    function refresh(): void {
        chooserController.refresh();
    }
    function cycleDetailsTab(): void {
        chooserController.cycleDetailsTab();
    }

    ChooserShortcuts {
        controller: surface.chooserController
        navigationEnabled: surface.navigationEnabled
        refreshEnabled: surface.refreshEnabled
        detailsTabEnabled: surface.detailsTabEnabled
        refreshAutoRepeat: surface.refreshAutoRepeat
        onRefreshRequested: surface.refresh()
        onDetailsTabRequested: surface.cycleDetailsTab()
    }

    SplitChooserLayout {
        id: chooser
        controller: surface.chooserController
        listComponent: surface.listComponent
        detailsComponent: surface.detailsComponent
    }
}
