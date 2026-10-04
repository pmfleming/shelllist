pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property bool navigationEnabled: true
    property bool sessionReady: true
    property string sessionContext: chooserController.viewMemory ? JSON.stringify([chooserController.viewMemory.key, chooserController.viewMemory.tab]) : ""
    readonly property DetailsNavigation detailsNavigation: chooser.detailsNavigation
    property bool refreshEnabled: navigationEnabled && !chooserController.actionInFlight
    property bool detailsTabEnabled: navigationEnabled && chooserController.detailsOpen && chooserController.hasSelection
    property bool refreshAutoRepeat: true
    readonly property real uiScale: 1
    readonly property ChooserListPane listItem: chooser.listItem
    readonly property Item detailsItem: chooser.detailsItem

    function refresh(): void {
        chooserController.navigationInteracted();
        chooserController.refresh();
    }
    function cycleDetailsTab(backwards: bool): void {
        chooserController.navigationInteracted();
        if (chooserController.viewMemory)
            chooserController.viewMemory.synchronize();
        const restoreContent = detailsNavigation.activeFocus;
        detailsNavigation.finishEditor(false);
        chooserController.cycleDetailsTab(backwards);
        if (restoreContent)
            detailsNavigation.focusContent(true);
    }
    function cycleRegion(backwards: bool): void {
        chooserController.navigationInteracted();
        if (chooserController.viewMemory)
            chooserController.viewMemory.synchronize();
        if (detailsNavigation.activeFocus) {
            detailsNavigation.cycleFocus(backwards);
            return;
        }
        if (!listItem)
            return;
        const regions = [listItem.focusSearch, listItem.focusList];
        if (chooserController.detailsOpen)
            regions.push(detailsNavigation.focusContent);
        const current = listItem.listFocused ? 1 : 0;
        const next = (current + (backwards ? -1 : 1) + regions.length) % regions.length;
        regions[next]();
    }
    function dismiss(): void {
        chooserController.navigationInteracted();
        if (chooserController.detailsOpen && (detailsNavigation.activeFocus || detailsNavigation.popupOpen))
            detailsNavigation.retreat();
        else
            chooserController.dismissNavigation();
    }

    ShortcutHints {
        objectName: "shortcutHints"
        scope: surface
        navigation: surface.detailsNavigation
        enabled: surface.chooserController.uiActive && !surface.chooserController.uiSuspending && surface.navigationEnabled && !surface.chooserController.navigationBlocked
        tabsEnabled: surface.detailsTabEnabled
    }

    ChooserShortcuts {
        controller: surface.chooserController
        navigationEnabled: surface.navigationEnabled
        refreshEnabled: surface.refreshEnabled
        detailsTabEnabled: surface.detailsTabEnabled && !surface.detailsNavigation.popupOpen
        refreshAutoRepeat: surface.refreshAutoRepeat
        onRefreshRequested: surface.refresh()
        onDetailsTabRequested: function (backwards) { surface.cycleDetailsTab(backwards); }
        function dismiss(): void {
            surface.dismiss();
        }
    }

    Shortcut {
        sequence: "Tab"
        enabled: surface.chooserController.uiActive && surface.navigationEnabled && !surface.detailsNavigation.commandMenuOpen
        onActivated: surface.cycleRegion(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        enabled: surface.chooserController.uiActive && surface.navigationEnabled && !surface.detailsNavigation.commandMenuOpen
        onActivated: surface.cycleRegion(true)
    }

    SplitChooserLayout {
        id: chooser
        controller: surface.chooserController
        detailsNavigation.headerShortcutsEnabled: surface.chooserController.uiActive && surface.chooserController.detailsOpen && surface.navigationEnabled
        navigationAllowed: surface.navigationEnabled
        sessionContext: surface.sessionContext
        sessionReady: surface.sessionReady
        listComponent: surface.listComponent
        detailsComponent: surface.detailsComponent
    }
}
