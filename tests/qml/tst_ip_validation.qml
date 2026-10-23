import QtQuick
import QtTest
import "../../qml/Shelllist/Ui/IpValidation.js" as Validation

// Former Node checks, now executed by the same JS engine as the editable controls.
TestCase {
    name: "IpValidation"
    function test_addresses_data() {
        const I = Validation.Intermediate, A = Validation.Acceptable, X = Validation.Invalid;
        const rows = [];
        for (const [family, cases] of [["ipv4", [["", I], ["1", I], ["192.168.1.", I], ["192.168.1.20", A], ["0.0.0.0", A], ["255.255.255.255", A], ["256.1.1.1", X], ["1..2.3", X], ["1.2.3.4.5", X], ["host.local", X]]], ["ipv6", [["", I], [":", I], ["2001:db8:", I], ["2001:db8::", A], ["::", A], ["::1", A], ["1:2:3:4:5:6:7:8", A], ["1:2:3:4:5:6:7", I], ["::ffff:192.168.", I], ["::ffff:192.168.1.1", A], ["1:2:3:4:5:6:192.0.2.1", A], ["1:::2", X], ["1::2::3", X], ["12345::1", X], ["1:2:3:4:5:6:7:8:", X], ["1:2:3:4:5:6:7:8:9", X], ["fe80::1%wlan0", X]]]])
            for (const [value, state] of cases)
                rows.push({
                    tag: family + ":" + value,
                    family: family,
                    value: value,
                    state: state
                });
        return rows;
    }
    function test_addresses(data) {
        compare(Validation.addressState(data.value, data.family), data.state);
    }
    function test_lists_prefixes_and_raw_buffer_limits() {
        const I = Validation.Intermediate, A = Validation.Acceptable, X = Validation.Invalid;
        for (const [value, family, empty, state] of [["", "ipv4", true, A], ["", "ipv4", false, I], ["1.1.1.1", "ipv4", false, A], ["1.1.1.1, 8.8.8.8", "ipv4", false, A], ["1.1.1.1,", "ipv4", false, I], ["1.1.1.1, 8.8", "ipv4", false, I], ["1.1, 8.8.8.8", "ipv4", false, X], ["1.1.1.1,,8.8.8.8", "ipv4", false, X], ["2001:4860:4860::8888, 2606:4700:4700::1111", "ipv6", false, A]])
            compare(Validation.addressInputState(value, family, true, empty), state, value);
        for (const [value, family, empty, state] of [["", "ipv4", false, I], ["", "ipv4", true, A], ["0", "ipv4", false, A], ["32", "ipv4", false, A], ["33", "ipv4", false, X], ["128", "ipv6", false, A], ["129", "ipv6", false, X], ["abc", "ipv6", false, X], ["24" + " ".repeat(Validation.MaximumEditingLength), "ipv4", false, X]])
            compare(Validation.prefixState(value, family, empty), state, value);
        for (const [value, family, multiple, state] of [["192.168.100.100/24", "ipv4", false, X], ["1.1.1.1\n8.8.8.8", "ipv4", true, A], ["2001:db8::\n::1", "ipv6", true, A], ["1.1.1.1,".repeat(65), "ipv4", true, X], ["1.1.1.1" + " ".repeat(Validation.MaximumEditingLength), "ipv4", false, X]])
            compare(Validation.addressInputState(value, family, multiple, false), state, value);
    }
    function test_diagnostics_match_acceptance_and_first_invalid_element() {
        for (const [value, family, multiple, prefix, key] of [["192.168.100.100/24", "ipv4", false, false, "cidr"], ["fe80::1%wlan0", "ipv6", false, false, "zone"], ["192.168.300.20", "ipv4", false, false, "octet"], ["1.1.1.1,", "ipv4", true, false, "empty-list-item"], ["129", "ipv6", false, true, "prefix"]])
            compare(Validation.issue(value, family, multiple, false, prefix).key, key);
        for (const [input, index, octet] of [["1.1.1.1, 192.300.400.1, 999.1.1.1", 2, 2], ["1.1.1.1 bad 999.1.1.1", 2, undefined], ["255.255.255.255, 1.2.3.999", 2, 4]]) {
            const issue = Validation.issue(input, "ipv4", true, false, false);
            compare(issue.index, index);
            compare(issue.octet, octet);
        }
        for (const prefix of [false, true])
            for (const multiple of [false, true])
                for (const empty of [false, true])
                    for (const value of ["", " ".repeat(Validation.MaximumEditingLength), (prefix ? "24" : "1.1.1.1").padEnd(Validation.MaximumEditingLength - 1), (prefix ? "24" : "1.1.1.1").padEnd(Validation.MaximumEditingLength)]) {
                        const state = prefix ? Validation.prefixState(value, "ipv4", empty) : Validation.addressInputState(value, "ipv4", multiple, empty);
                        const issue = Validation.issue(value, "ipv4", multiple, empty, prefix);
                        compare(issue === null, state === Validation.Acceptable);
                        if (value.length >= Validation.MaximumEditingLength)
                            compare(issue.key, "buffer");
                    }
    }
}
