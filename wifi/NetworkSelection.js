.pragma library
.import "WifiPresentation.js" as Presentation

function clampIndex(index, length) { return length <= 0 ? 0 : Math.max(0, Math.min(index, length - 1)); }
function sameNetwork(left, right) { return !!(left && right && left.key && right.key && left.key === right.key); }
function networkMatches(network, query) { return !query || Presentation.valueOr(network, "ssid", "").toLowerCase().indexOf(query) !== -1; }
function compareNetworks(left, right) {
    const activityDelta = Number(!!right.active) - Number(!!left.active);
    const strengthDelta = Presentation.valueOr(right, "strength", 0) - Presentation.valueOr(left, "strength", 0);
    return activityDelta || strengthDelta || Presentation.networkName(left).localeCompare(Presentation.networkName(right));
}
function visibleNetworks(networks, filterText) {
    const query = (filterText || "").toLowerCase();
    return networks.filter(function (network) { return networkMatches(network, query); }).sort(compareNetworks);
}
function selectedNetwork(networks, selectedIndex) {
    return networks.length === 0 ? null : networks[clampIndex(selectedIndex, networks.length)];
}
function selectedIndexAfterUpdate(previous, networks, selectedIndex, resetSelection) {
    if (resetSelection || !previous) {
        const activeIndex = networks.findIndex(function (network) { return !!network.active; });
        return activeIndex >= 0 ? activeIndex : 0;
    }
    const nextIndex = networks.findIndex(function (network) { return sameNetwork(previous, network); });
    return nextIndex >= 0 ? nextIndex : clampIndex(selectedIndex, networks.length);
}
