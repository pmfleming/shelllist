pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property alias minimumSplitDetailsWidth: chooser.minimumSplitDetailsWidth
    property bool navigationEnabled: true
    // Incremental migration: native dialogs and unmigrated domains stay intact.
    property bool keyboardWorkflow: false
    readonly property alias detailsNavigation: chooser.detailsNavigation
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
        const restoreContent = keyboardWorkflow && detailsNavigation.activeFocus;
        chooserController.cycleDetailsTab();
        if (restoreContent)
            detailsNavigation.focusContent(true);
    }
    function cycleRegion(backwards: bool): void {
        if (!listItem)
            return;
        const inDetails = detailsNavigation.activeFocus;
        const inResults = listItem.listFocused;
        if (backwards) {
            if (inDetails)
                listItem.focusList();
            else if (inResults)
                listItem.focusSearch();
            else if (chooserController.detailsOpen)
                detailsNavigation.focusContent();
            else
                listItem.focusList();
        } else {
            if (inDetails)
                listItem.focusSearch();
            else if (inResults && chooserController.detailsOpen)
                detailsNavigation.focusContent();
            else if (inResults)
                listItem.focusSearch();
            else
                listItem.focusList();
        }
    }
    function dismiss(): void {
        if (keyboardWorkflow && chooserController.detailsOpen && (detailsNavigation.activeFocus || detailsNavigation.popupOpen))
            detailsNavigation.retreat();
        else
            chooserController.dismissNavigation();
    }

    ChooserShortcuts {
        controller: surface.chooserController
        navigationEnabled: surface.navigationEnabled
        refreshEnabled: surface.refreshEnabled
        detailsTabEnabled: surface.detailsTabEnabled && (!surface.keyboardWorkflow || !surface.detailsNavigation.popupOpen)
        refreshAutoRepeat: surface.refreshAutoRepeat
        onRefreshRequested: surface.refresh()
        onDetailsTabRequested: surface.cycleDetailsTab()
        function dismiss(): void {
            surface.dismiss();
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+S"
        enabled: surface.keyboardWorkflow && surface.chooserController.uiActive && surface.navigationEnabled && !surface.chooserController.actionInFlight
        autoRepeat: false
        onActivated: surface.chooserController.screenshotRequested()
    }
    Shortcut {
        sequence: "Tab"
        enabled: surface.keyboardWorkflow && surface.chooserController.uiActive && surface.navigationEnabled && !surface.detailsNavigation.popupOpen
        onActivated: surface.cycleRegion(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        enabled: surface.keyboardWorkflow && surface.chooserController.uiActive && surface.navigationEnabled && !surface.detailsNavigation.popupOpen
        onActivated: surface.cycleRegion(true)
    }

    SplitChooserLayout {
        id: chooser
        controller: surface.chooserController
        keyboardWorkflow: surface.keyboardWorkflow
        listComponent: surface.listComponent
        detailsComponent: surface.detailsComponent
    }
}
