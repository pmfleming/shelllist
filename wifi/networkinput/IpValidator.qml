pragma Singleton

import QtQuick
import "IpValidation.js" as Validation

QtObject {
    function ipv4State(value) { return Validation.ipv4State(value); }
    function ipv6State(value) { return Validation.ipv6State(value); }
    function addressState(value, family) { return Validation.addressState(value, family); }
    function addressInputState(value, family, multiple, allowEmpty) {
        return Validation.addressInputState(value, family, multiple, allowEmpty);
    }
    function prefixState(value, family, allowEmpty) {
        return Validation.prefixState(value, family, allowEmpty);
    }
    function isIpv4(value) { return Validation.isIpv4(value); }
    function isIpv6(value) { return Validation.isIpv6(value); }
    function isAddress(value, family) { return Validation.isAddress(value, family); }
    function isAddressInput(value, family, multiple, allowEmpty) {
        return Validation.isAddressInput(value, family, multiple, allowEmpty);
    }
    function isPrefix(value, family, allowEmpty) {
        return Validation.isPrefix(value, family, allowEmpty);
    }
}
