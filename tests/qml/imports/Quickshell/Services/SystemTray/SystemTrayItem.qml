import QtQuick
// System-tray platform boundary; no application is activated by unit tests.
QtObject {
    property string id: ""
    property string title: ""
    property string icon: ""
    property string tooltipTitle: ""
    property string tooltipDescription: ""
    property QtObject menu: null
    property bool hasMenu: false
    property bool onlyMenu: false
    property int activationCount: 0
    property int secondaryCount: 0
    property int scrollTotal: 0
    property int menuCount: 0
    function activate(): void { activationCount++; }
    function secondaryActivate(): void { secondaryCount++; }
    function scroll(delta: int, horizontal: bool): void { scrollTotal += delta; }
    function display(window: QtObject, x: int, y: int): void { menuCount++; }
}
