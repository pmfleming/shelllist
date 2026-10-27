import QtQuick

// A single-content-region counterpart of ProviderChooserSurface. The domain
// retains tabs, drafts and dismissal policy; this owns only ordinary focus.
ChooserSurface {
    id: surface
    required property ChooserController chooserController
    readonly property DetailsNavigation detailsNavigation: navigation
    default property alias panelContent: body.data
    // Non-field regions share surface lifecycle, commands and modal guards.
    property DateGridNavigation scopedNavigation: null
    property bool navigationEnabled: true
    property bool focusOnActivation: true
    property int region: 0
    property Item navigationContent: body
    property bool pendingFocus: false
    property bool consumed: false
    readonly property bool focusReady: visible && enabled && Window.window !== null && navigation.contentReady && !chooserController.navigationBlocked
    property bool feedbackEnabled: false
    property string feedbackText: ""
    property string feedbackSummary: qsTr("Operation needs attention")
    property string feedbackTone: "error"

    function snapshot(): void {
        chooserController.focusMemory = {context: context(), region: region, location: navigation.activeFocus ? navigation.locationState() : navigation.lastLocation};
    }
    function context(): string {
        const memory = chooserController.viewMemory;
        return memory ? JSON.stringify([memory.key, memory.tab]) : "";
    }
    function requestFocus(): void {
        if (!focusOnActivation || consumed || !chooserController.uiActive || chooserController.uiSuspending || chooserController.navigationBlocked)
            return;
        consumed = true;
        pendingFocus = true;
        Qt.callLater(restore, chooserController.uiGeneration);
    }
    // A retained or incubated standalone view must not depend on a host signal
    // delivered before its Connections existed. Wait for attachment/content,
    // then consume focus once; later input still cancels queued restoration.
    Component.onCompleted: requestFocus()
    onFocusReadyChanged: if (focusReady && pendingFocus)
        Qt.callLater(restore, chooserController.uiGeneration)
    function restore(generation: int): void {
        if (!focusOnActivation) { pendingFocus = false; return; }
        if (!pendingFocus || !focusReady || generation !== chooserController.uiGeneration || !chooserController.uiActive || chooserController.uiSuspending)
            return;
        pendingFocus = false;
        if (chooserController.viewMemory)
            chooserController.viewMemory.synchronize();
        const saved = chooserController.focusMemory;
        region = Number.isFinite(saved.region) ? saved.region : 0;
        if (scopedNavigation) {
            scopedNavigation.focusContent();
            return;
        }
        if (saved.context === context())
            navigation.focusSessionLocation(saved.location);
        else
            navigation.focusContent(true);
    }
    function cycleRegion(backwards: bool): void {
        pendingFocus = false;
        if (scopedNavigation) scopedNavigation.focusContent();
        else navigation.cycleFocus(backwards);
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
        enabled: surface.navigationEnabled && surface.chooserController.uiActive && !surface.chooserController.uiSuspending && !surface.chooserController.navigationBlocked
        tabsEnabled: surface.scopedNavigation === null
    }
    DetailsNavigation {
        id: navigation
        anchors.fill: parent
        contentItem: surface.navigationContent
        fieldController: surface.chooserController
        headerContentItem: body
        headerShortcutsEnabled: surface.navigationEnabled && surface.chooserController.uiActive && !surface.chooserController.navigationBlocked
        restorationAllowed: surface.chooserController.uiActive && !surface.chooserController.uiSuspending && !surface.chooserController.navigationBlocked
        viewMemory: surface.chooserController.viewMemory
        onInteractionRequested: surface.pendingFocus = false
        onNativeFocusChanged: if (!applyingMemory) surface.pendingFocus = false
        onExitRequested: surface.chooserController.dismissNavigation()
        Item {
            id: body
            anchors.fill: parent
            anchors.bottomMargin: surface.feedbackEnabled ? Theme.statusHeight + Theme.spacingMd : 0
        }
    }
    StatusPanel {
        objectName: "panelFeedback"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.contentMargin
        visible: surface.feedbackEnabled
        uiScale: 1
        status: surface.feedbackText
        statusSummary: surface.feedbackSummary
        statusTone: surface.feedbackTone
        feedbackScope: body
    }
    Shortcut {
        sequence: "Escape"
        enabled: surface.navigationEnabled && surface.chooserController.uiActive && !surface.chooserController.navigationBlocked
        onActivated: navigation.retreat()
    }
    Shortcut {
        sequence: "Tab"
        enabled: surface.navigationEnabled && surface.chooserController.uiActive && !surface.chooserController.navigationBlocked && !navigation.commandMenuOpen
        onActivated: surface.cycleRegion(false)
    }
    Shortcut {
        sequence: "Shift+Tab"
        enabled: surface.navigationEnabled && surface.chooserController.uiActive && !surface.chooserController.navigationBlocked && !navigation.commandMenuOpen
        onActivated: surface.cycleRegion(true)
    }
    Connections {
        target: surface.chooserController
        function onNavigationInteracted(): void { surface.pendingFocus = false; navigation.cancelSessionRestore(); }
        function onRestoreSessionFocusRequested(): void { surface.requestFocus(); }
        function onFocusSearchRequested(): void { surface.requestFocus(); }
        function onNavigationBlockedChanged(): void {
            if (surface.chooserController.navigationBlocked)
                surface.pendingFocus = false;
        }
        function onUiSuspensionRequested(): void {
            surface.snapshot();
            surface.pendingFocus = false;
            navigation.suspendView();
        }
        function onUiActiveChanged(): void {
            surface.pendingFocus = false;
            surface.consumed = false;
            surface.requestFocus();
        }
    }
}
