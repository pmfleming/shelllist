import QtQuick
import QtQuick.Window

// Private compositor fixture: normal close must preserve the client and the
// newly created save dialog. The Rust harness owns process cleanup afterward.
Window {
    id: document
    visible: true
    width: 240
    height: 160
    title: "Workspace close veto fixture"
    onClosing: function(close) {
        close.accepted = false;
        saveDialog.visible = true;
    }
    Window {
        id: saveDialog
        visible: false
        width: 200
        height: 120
        title: "Unsaved document fixture"
        transientParent: document
    }
}
