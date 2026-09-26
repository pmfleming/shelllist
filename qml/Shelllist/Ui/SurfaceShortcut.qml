import QtQuick

// List this shortcut in the surface's helpShortcuts to include its help text
// in the navigation dialog. The binding and description share one declaration.
Shortcut {
    property string help: ""
    property string keys: String(sequence).replace("Return", "Enter")
}
