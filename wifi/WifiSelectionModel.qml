import QtQuick
import "Wifi.js" as Wifi

Item {
    property var networks: []
    property var activeAccessPoint: null
    property string filterText: ""
    property int selectedIndex: 0
    readonly property var filteredNetworks: Wifi.visibleNetworks(networks, filterText, activeAccessPoint)

    function selected() { return Wifi.selectedNetwork(filteredNetworks, selectedIndex); }

    function apply(newNetworks, resetSelection) {
        const previous = selected();
        networks = newNetworks;
        selectedIndex = Wifi.selectedIndexAfterUpdate(
            previous,
            filteredNetworks,
            selectedIndex,
            resetSelection,
            function (network) { return Wifi.isActiveAccessPoint(network, activeAccessPoint); }
        );
    }

    function move(delta) {
        selectedIndex = Wifi.clampIndex(selectedIndex + delta, filteredNetworks.length);
    }
}
