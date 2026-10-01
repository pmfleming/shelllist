pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property bool navigationEnabled: true
    // Incremental migration: native dialogs and unmigrated domains stay intact.
    property bool keyboardWorkflow: false
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
        const restoreContent = keyboardWorkflow && detailsNavigation.activeFocus;
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
        const next = detailsNavigation.activeFocus ? (backwards ? 1 : 0) : (current + (backwards ? -1 : 1) + regions.length) % regions.length;
        regions[next]();
    }
    function dismiss(): void {
        chooserController.navigationInteracted();
        if (keyboardWorkflow && chooserController.detailsOpen && (detailsNavigation.activeFocus || detailsNavigation.popupOpen))
            detailsNavigation.retreat();
        else
            chooserController.dismissNavigation();
    }

    ShortcutHints {
        objectName: "shortcutHints"
        scope: surface
        navigation: surface.detailsNavigation
        enabled: surface.keyboardWorkflow && surface.chooserController.uiActive && !surface.chooserController.uiSuspending && surface.navigationEnabled && !surface.chooserController.navigationBlocked
        tabsEnabled: surface.detailsTabEnabled
    }

    ChooserShortcuts {
        controller: surface.chooserController
        navigationEnabled: surface.navigationEnabled
        refreshEnabled: surface.refreshEnabled
        detailsTabEnabled: surface.detailsTabEnabled && (!surface.keyboardWorkflow || !surface.detailsNavigation.popupOpen)
        refreshAutoRepeat: surface.refreshAutoRepeat
        onRefreshRequested: surface.refresh()
        onDetailsTabRequested: function (backwards) { surface.cycleDetailsTab(backwards); }
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
        detailsNavigation.headerShortcutsEnabled: surface.keyboardWorkflow && surface.chooserController.uiActive && surface.chooserController.detailsOpen && surface.navigationEnabled
        navigationAllowed: surface.navigationEnabled
        sessionContext: surface.sessionContext
        sessionReady: surface.sessionReady
        listComponent: surface.listComponent
        detailsComponent: surface.detailsComponent
    }
}
