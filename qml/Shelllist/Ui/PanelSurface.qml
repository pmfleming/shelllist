import QtQuick

// A single-content-region counterpart of ProviderChooserSurface. The domain
// retains tabs, drafts and dismissal policy; this owns only ordinary focus.
ChooserSurface {
    id: surface
    required property ChooserController chooserController
    readonly property DetailsNavigation detailsNavigation: navigation
    default property alias panelContent: body.data
    property int region: 0
    property Item navigationContent: body
    property bool pendingFocus: false
    property bool consumed: false

    function snapshot(): void {
        chooserController.focusMemory = {context: context(), region: region, location: navigation.activeFocus ? navigation.locationState() : navigation.lastLocation};
    }
    function context(): string {
        const memory = chooserController.viewMemory;
        return memory ? JSON.stringify([memory.key, memory.tab]) : "";
    }
    function restore(generation: int): void {
        if (!pendingFocus || generation !== chooserController.uiGeneration || !chooserController.uiActive || chooserController.uiSuspending)
            return;
        pendingFocus = false;
        chooserController.viewMemory.synchronize();
        const saved = chooserController.focusMemory;
        region = Number.isFinite(saved.region) ? saved.region : 0;
        if (saved.context === context())
            navigation.focusSessionLocation(saved.location);
        else
            navigation.focusContent(true);
    }
    function cycleRegion(backwards: bool): void {
        pendingFocus = false;
        navigation.cycleFocus(backwards);
    }
    function changeTab(backwards: bool): void {
        chooserController.navigationInteracted();
        navigation.finishEditor(false);
        chooserController.cycleDetailsTab(backwards);
        navigation.focusContent(true);
    }
    ShortcutHints {
        objectName: "shortcutHints"
        scope: surface
        navigation: surface.detailsNavigation
        enabled: surface.chooserController.uiActive && !surface.chooserController.uiSuspending && !surface.chooserController.navigationBlocked
        tabsEnabled: true
    }
    DetailsNavigation {
        id: navigation
        anchors.fill: parent
        contentItem: surface.navigationContent
        headerContentItem: body
        headerShortcutsEnabled: surface.chooserController.uiActive && !surface.chooserController.navigationBlocked
        restorationAllowed: surface.chooserController.uiActive && !surface.chooserController.uiSuspending && !surface.chooserController.navigationBlocked
        viewMemory: surface.chooserController.viewMemory
        onInteractionRequested: surface.pendingFocus = false
        onNativeFocusChanged: if (!applyingMemory) surface.pendingFocus = false
        onExitRequested: surface.chooserController.dismissNavigation()
        Item { id: body; anchors.fill: parent }
    }
    Shortcut {
        sequence: "Escape"
        enabled: surface.chooserController.uiActive && !surface.chooserController.navigationBlocked
        onActivated: navigation.retreat()
    }
    Shortcut {
        sequence: "Tab"
        enabled: surface.chooserController.uiActive && !surface.chooserController.navigationBlocked && !navigation.commandMenuOpen
        onActivated: surface.cycleRegion(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        enabled: surface.chooserController.uiActive && !surface.chooserController.navigationBlocked && !navigation.commandMenuOpen
        onActivated: surface.cycleRegion(true)
    }
    Connections {
        target: surface.chooserController
        function onNavigationInteracted(): void { surface.pendingFocus = false; navigation.cancelSessionRestore(); }
        function onRestoreSessionFocusRequested(): void {
            if (surface.consumed || !surface.chooserController.uiActive || surface.chooserController.uiSuspending)
                return;
            surface.consumed = true;
            surface.pendingFocus = true;
            Qt.callLater(surface.restore, surface.chooserController.uiGeneration);
        }
        function onUiSuspensionRequested(): void {
            surface.snapshot();
            surface.pendingFocus = false;
            navigation.suspendView();
        }
        function onUiActiveChanged(): void {
            surface.pendingFocus = false;
            surface.consumed = false;
        }
    }
}
