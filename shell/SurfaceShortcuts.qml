pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "SurfaceCatalog.generated.js" as Catalog

// Only shortcut metadata is data-driven. Surface factories stay explicitly typed
// in SurfaceRegistry; these delegates never construct panels or call backends.
Item {
    id: shortcuts
    signal surfaceRequested(string surfaceId)

    Repeater {
        model: Catalog.shortcuts
        delegate: Ui.ShelllistGlobalShortcut {
            required property var modelData
            objectName: "surfaceShortcut-" + modelData.id
            shortcutName: modelData.id
            description: modelData.description
            onTriggered: shortcuts.surfaceRequested(modelData.id)
        }
    }
}
