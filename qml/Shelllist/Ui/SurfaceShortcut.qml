import QtQuick

// A chooser-surface shortcut that also lists itself in the navigation help
// dialog when it has help text, so the binding and its description share one
// declaration.
Shortcut {
    property string help: ""
    property string keys: String(sequence).replace("Return", "Enter")
}
