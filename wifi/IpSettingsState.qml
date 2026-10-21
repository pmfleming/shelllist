import QtQuick
import Shelllist.Ui as Ui

QtObject {
    required property string family

    property string method: "auto"
    // Atomic domain draft: invalid address/mask text survives field saves and
    // continues blocking the whole group, including after page recreation.
    property string addressWithSubnet: ""
    readonly property var addressInput: Ui.IpCodec.inspect(addressWithSubnet, family, "addressWithSubnet", "prefix", false)
    property string gateway: ""
    property bool autoDns: true
    property string dns: ""
    property string search: ""

    function valueOr(value, fallback) {
        return value || fallback;
    }
    function list(value) {
        return valueOr(value, []);
    }
    function splitValues(value) {
        return String(valueOr(value, "")).split(/[\s,]+/).filter(function (entry) {
            return entry.length > 0;
        });
    }
    function firstAddress(settings) {
        const addresses = list(settings.addresses);
        return addresses.length > 0 ? addresses[0] : ({});
    }
    function sync(settings) {
        const value = valueOr(settings, ({}));
        const first = firstAddress(value);
        method = valueOr(value.method, "auto");
        const address = valueOr(first.address, "");
        const prefix = first.prefix === undefined || first.prefix === null ? "" : String(first.prefix);
        addressWithSubnet = address || prefix ? address + "/" + prefix : "";
        gateway = valueOr(value.gateway, "");
        autoDns = !value.ignore_auto_dns;
        dns = list(value.dns).join(", ");
        search = list(value.dns_search).join(", ");
    }

    function setAutoDns(value) {
        autoDns = !!value;
    }

    function manualAddresses() {
        if (method !== "manual" || !addressInput.valid)
            return [];
        return [{address: addressInput.address, prefix: addressInput.prefixLength}];
    }
    function optionalGateway() {
        const value = gateway.trim();
        return value.length > 0 ? value : null;
    }
    function routeMetric(source) {
        return source.route_metric === undefined ? null : source.route_metric;
    }
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
        return addressInput.valid;
    }
    function dnsReady() {
        return autoDns || Ui.IpValidation.isAddressInput(dns, family, true, true);
    }
    function ready() {
        return manualReady() && Ui.IpValidation.isAddressInput(gateway, family, false, true) && dnsReady();
    }
}
