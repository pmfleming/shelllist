import QtQuick

// Common chooser selection contract. Owners decide when catalog changes clamp
// or restore selection; this model never reacts to count changes on its own.
Item {
    property int selectedIndex: 0
    property int count: 0
    property string queryText: ""

    function clampIndex(index: int): int {
        return count <= 0 ? 0 : Math.max(0, Math.min(index, count - 1));
    }
    function move(delta: int): void {
        selectedIndex = clampIndex(selectedIndex + delta);
    }
    function selectFirst(): void {
        selectedIndex = 0;
    }
}
