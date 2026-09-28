import QtQuick
// Native-menu platform boundary. The real engine still owns the chooser focus.
QtObject {
    component Anchor: QtObject { property Item item: null }
    property Anchor anchor: Anchor {}
    property QtObject menu: null
    property bool visible: false
    signal opened
    signal closed
    function open(): void { if (menu) { visible = true; opened(); } }
    function close(): void { if (visible) { visible = false; closed(); } }
}
