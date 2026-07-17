import QtQuick
import "NetworkSelection.js" as NetworkSelection

Item {
    property var networks: []
    property string filterText: ""
    property int selectedIndex: 0
    readonly property var filteredNetworks: NetworkSelection.visibleNetworks(networks, filterText)

    function selected() { return NetworkSelection.selectedNetwork(filteredNetworks, selectedIndex); }

    function apply(newNetworks, resetSelection) {
        const previous = selected();
        networks = newNetworks;
        selectedIndex = NetworkSelection.selectedIndexAfterUpdate(previous, filteredNetworks, selectedIndex, resetSelection);
    }

    function move(delta) {
        selectedIndex = NetworkSelection.clampIndex(selectedIndex + delta, filteredNetworks.length);
    }
}
