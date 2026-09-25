pragma ComponentBehavior: Bound

import QtQuick

ChooserSurface {
    id: surface

    required property ChooserController chooserController
    required property Component listComponent
    required property Component detailsComponent
    property string surfaceName: "Shelllist"
    property alias minimumSplitDetailsWidth: chooser.minimumSplitDetailsWidth
    // Hints for keys handled outside SurfaceShortcut, e.g. list navigation.
    property var helpEntries: []
    property string refreshHelp: ""
    property string detailsTabHelp: qsTr("Cycle detail tabs")
    property bool navigationEnabled: !chooserController.navigationHelpOpen
    property bool refreshEnabled: navigationEnabled && !chooserController.actionInFlight
    property bool detailsTabEnabled: navigationEnabled && chooserController.detailsOpen && chooserController.hasSelection
    property bool refreshAutoRepeat: true
    property bool helpEnabled: chooserController.uiActive
    readonly property real uiScale: Theme.densityScale(height, chooserController.contentVerticalMargin)
    readonly property ChooserListPane listItem: chooser.listItem
    readonly property Item detailsItem: chooser.detailsItem
    readonly property var allHelpEntries: helpEntries.concat(shortcutHelpEntries(), refreshHelp ? [{
            keys: "F5",
            action: refreshHelp
        }] : [], detailsTabHelp ? [{
            keys: "Ctrl+Tab",
            action: detailsTabHelp
        }] : [])

    function refresh(): void {
        chooserController.refresh();
    }
    function cycleDetailsTab(): void {
        chooserController.cycleDetailsTab();
    }
    function shortcutHelpEntries(): var {
        const entries = [];
        for (let index = 0; index < resources.length; ++index) {
            const shortcut = resources[index] as SurfaceShortcut;
            if (shortcut && shortcut.help)
                entries.push({
                    keys: shortcut.keys,
                    action: shortcut.help
                });
        }
        return entries;
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

    NavigationHelpDialog {
        controller: surface.chooserController
        surfaceName: surface.surfaceName
        helpEnabled: surface.helpEnabled
        entries: surface.allHelpEntries
    }
}
