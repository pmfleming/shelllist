.pragma library

var Invalid = 0;
var Intermediate = 1;
var Acceptable = 2;

function normalizedFamily(family) {
    return String(family || "").toLowerCase() === "ipv6" ? "ipv6" : "ipv4";
}

function ipv4PartState(part, finalPart) {
    if (part.length === 0)
        return finalPart ? Intermediate : Invalid;
    return /^\d{1,3}$/.test(part) && Number(part) <= 255 ? Acceptable : Invalid;
}

function ipv4State(value) {
    const address = String(value || "").trim();
    if (address.length === 0)
        return Intermediate;
    if (!/^[0-9.]+$/.test(address))
        return Invalid;
    const parts = address.split(".");
    if (parts.length > 4 || parts[0].length === 0)
        return Invalid;
    for (let index = 0; index < parts.length; ++index) {
        const state = ipv4PartState(parts[index], index === parts.length - 1);
        if (state !== Acceptable)
            return state;
    }
    return parts.length === 4 ? Acceptable : Intermediate;
}

function isIpv4(value) {
    return ipv4State(value) === Acceptable;
}

function ipv6PartResult(part, finalPart, allowPartial) {
    if (part.length === 0)
        return { valid: false, units: 0, incomplete: false };
    if (part.indexOf(".") < 0)
        return { valid: /^[0-9a-fA-F]{1,4}$/.test(part), units: 1, incomplete: false };
    if (!finalPart)
        return { valid: false, units: 0, incomplete: false };
    const state = ipv4State(part);
    return { valid: allowPartial ? state !== Invalid : state === Acceptable, units: 2, incomplete: state === Intermediate };
}

function measureIpv6Parts(parts, allowPartial) {
    let result = { valid: true, units: 0, incomplete: false };
    for (let index = 0; index < parts.length; ++index) {
        const part = ipv6PartResult(parts[index], index === parts.length - 1, allowPartial);
        if (!part.valid)
            return { valid: false, units: 0, incomplete: false };
        result.units += part.units;
        result.incomplete = result.incomplete || part.incomplete;
    }
    return result;
}

function ipv6UnitCount(parts) {
    const result = measureIpv6Parts(parts, false);
    return result.valid ? result.units : -1;
}

function splitNonEmpty(value) { return value.length > 0 ? value.split(":") : []; }
function splitIpv6(address) {
    const compression = address.indexOf("::");
    if (compression < 0)
        return { compressed: false, parts: address.split(":") };
    return {
        compressed: true,
        parts: splitNonEmpty(address.slice(0, compression)).concat(splitNonEmpty(address.slice(compression + 2)))
    };
}
function hasRepeatedCompression(address) {
    const compression = address.indexOf("::");
    return compression >= 0 && address.indexOf("::", compression + 2) >= 0;
}
function hasMalformedEmbeddedIpv4(address) {
    return address.indexOf(".") >= 0 && !/\d{1,3}(?:\.\d{1,3}){3}$/.test(address);
}

function isIpv6Complete(value) {
    const address = String(value || "").trim();
    if (address.length === 0 || address.indexOf("%") >= 0 || hasRepeatedCompression(address) || hasMalformedEmbeddedIpv4(address))
        return false;
    const parsed = splitIpv6(address);
    const units = ipv6UnitCount(parsed.parts);
    if (parsed.compressed)
        return units >= 0 && units < 8;
    return address[0] !== ":" && address[address.length - 1] !== ":" && units === 8;
}

function partialIpv6Units(parts) { return measureIpv6Parts(parts, true); }

function invalidPartialIpv6Syntax(address) {
    return !/^[0-9a-fA-F:.]+$/.test(address)
        || address.indexOf("%") >= 0
        || address.indexOf(":::") >= 0
        || hasRepeatedCompression(address);
}

function partialIpv6State(result, compressed, trailingSeparator) {
    if (!result.valid)
        return Invalid;
    if (compressed)
        return result.units < 8 ? Intermediate : Invalid;
    if (result.units > 8 || (trailingSeparator && result.units >= 8))
        return Invalid;
    return result.incomplete || result.units < 8 ? Intermediate : Invalid;
}

function ipv6State(value) {
    const address = String(value || "").trim();
    if (address.length === 0 || address === ":")
        return Intermediate;
    if (isIpv6Complete(address))
        return Acceptable;
    if (invalidPartialIpv6Syntax(address))
        return Invalid;
    const trailingSeparator = address.endsWith(":") && !address.endsWith("::");
    const candidate = trailingSeparator ? address.slice(0, -1) : address;
    const parsed = splitIpv6(candidate);
    if (!parsed.compressed && candidate[0] === ":")
        return Invalid;
    return partialIpv6State(partialIpv6Units(parsed.parts), parsed.compressed, trailingSeparator);
}

function isIpv6(value) {
    return ipv6State(value) === Acceptable;
}

function addressState(value, family) {
    return normalizedFamily(family) === "ipv6" ? ipv6State(value) : ipv4State(value);
}

function isAddress(value, family) {
    return addressState(value, family) === Acceptable;
}

function groupedAddressState(value, family, finalAddress) {
    const state = addressState(value, family);
    if (state === Invalid)
        return Invalid;
    return finalAddress || state === Acceptable ? state : Invalid;
}

function addressGroupState(group, family, finalGroup) {
    if (group.length === 0)
        return finalGroup ? Intermediate : Invalid;
    const addresses = group.split(/\s+/);
    for (let index = 0; index < addresses.length; ++index) {
        const finalAddress = finalGroup && index === addresses.length - 1;
        const state = groupedAddressState(addresses[index], family, finalAddress);
        if (state !== Acceptable)
            return state;
    }
    return Acceptable;
}

function addressInputState(value, family, multiple, allowEmpty) {
    const input = String(value || "").trim();
    if (input.length === 0)
        return allowEmpty ? Acceptable : Intermediate;
    if (!multiple)
        return addressState(input, family);
    if (input[0] === ",")
        return Invalid;
    const groups = input.split(",");
    for (let index = 0; index < groups.length; ++index) {
        const state = addressGroupState(groups[index].trim(), family, index === groups.length - 1);
        if (state !== Acceptable)
            return state;
    }
    return Acceptable;
}

function isAddressInput(value, family, multiple, allowEmpty) {
    return addressInputState(value, family, multiple, allowEmpty) === Acceptable;
}

function prefixState(value, family, allowEmpty) {
    const input = String(value || "").trim();
    if (input.length === 0)
        return allowEmpty ? Acceptable : Intermediate;
    if (!/^\d{1,3}$/.test(input))
        return Invalid;
    const maximum = normalizedFamily(family) === "ipv6" ? 128 : 32;
    return Number(input) <= maximum ? Acceptable : Invalid;
}

function isPrefix(value, family, allowEmpty) {
    return prefixState(value, family, allowEmpty) === Acceptable;
}
