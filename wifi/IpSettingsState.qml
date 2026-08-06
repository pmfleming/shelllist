import QtQuick
import "networkinput" as NetworkInput

QtObject {
    required property string family
    required property int fallbackPrefix

    property string method: "auto"
    property string address: ""
    property string prefix: String(fallbackPrefix)
    property string gateway: ""
    property bool autoDns: true
    property string dns: ""
    property string search: ""

    function valueOr(value, fallback) { return value || fallback; }
    function list(value) { return valueOr(value, []); }
    function splitValues(value) {
        return String(valueOr(value, "")).split(/[\s,]+/)
            .filter(function (entry) { return entry.length > 0; });
    }
    function firstAddress(settings) {
        const addresses = list(settings.addresses);
        return addresses.length > 0 ? addresses[0] : ({});
    }
    function prefixValue(value) { return value === undefined ? fallbackPrefix : value; }

    function sync(settings) {
        const value = valueOr(settings, ({}));
        const first = firstAddress(value);
        method = valueOr(value.method, "auto");
        address = valueOr(first.address, "");
        prefix = String(prefixValue(first.prefix));
        gateway = valueOr(value.gateway, "");
        autoDns = !value.ignore_auto_dns;
        dns = list(value.dns).join(", ");
        search = list(value.dns_search).join(", ");
    }

    function setAutoDns(value) { autoDns = !!value; }

    function manualAddresses() {
        if (method !== "manual")
            return [];
        const value = address.trim();
        return value.length > 0 ? [{ address: value, prefix: Math.max(0, parseInt(prefix, 10) || 0) }] : [];
    }
    function optionalGateway() {
        const value = gateway.trim();
        return value.length > 0 ? value : null;
    }
    function routeMetric(source) { return source.route_metric === undefined ? null : source.route_metric; }
    function payload(source) {
        const value = valueOr(source, ({}));
        return {
            method: method,
            addresses: manualAddresses(),
            gateway: optionalGateway(),
            dns: autoDns ? [] : splitValues(dns),
            routes: list(value.routes),
            route_metric: routeMetric(value),
            ignore_auto_dns: !autoDns,
            dns_search: splitValues(search)
        };
    }

    function manualReady() {
        if (method !== "manual")
            return true;
        return NetworkInput.IpValidator.isAddressInput(address, family, false, false)
            && NetworkInput.IpValidator.isPrefix(prefix, family, false);
    }
    function dnsReady() {
        return autoDns || NetworkInput.IpValidator.isAddressInput(dns, family, true, true);
    }
    function ready() {
        return manualReady()
            && NetworkInput.IpValidator.isAddressInput(gateway, family, false, true)
            && dnsReady();
    }
}
