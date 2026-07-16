.pragma library

var Invalid = 0;
var Intermediate = 1;
var Acceptable = 2;

function normalizedFamily(family) {
    return String(family || "").toLowerCase() === "ipv6" ? "ipv6" : "ipv4";
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
        const part = parts[index];
        if (part.length === 0)
            return index === parts.length - 1 && parts.length <= 4 ? Intermediate : Invalid;
        if (!/^\d{1,3}$/.test(part) || Number(part) > 255)
            return Invalid;
    }
    return parts.length === 4 ? Acceptable : Intermediate;
}

function isIpv4(value) {
    return ipv4State(value) === Acceptable;
}

function ipv6UnitCount(parts) {
    let units = 0;
    for (let index = 0; index < parts.length; ++index) {
        const part = parts[index];
        if (part.length === 0)
            return -1;
        if (part.indexOf(".") >= 0) {
            if (index !== parts.length - 1 || !isIpv4(part))
                return -1;
            units += 2;
        } else {
            if (!/^[0-9a-fA-F]{1,4}$/.test(part))
                return -1;
            units += 1;
        }
    }
    return units;
}

function isIpv6Complete(value) {
    const address = String(value || "").trim();
    if (address.length === 0 || address.indexOf("%") >= 0)
        return false;

    const compression = address.indexOf("::");
    if (compression >= 0 && address.indexOf("::", compression + 2) >= 0)
        return false;
    if (address.indexOf(".") >= 0 && !/\d{1,3}(?:\.\d{1,3}){3}$/.test(address))
        return false;

    if (compression < 0) {
        if (address[0] === ":" || address[address.length - 1] === ":")
            return false;
        return ipv6UnitCount(address.split(":")) === 8;
    }

    const leftText = address.slice(0, compression);
    const rightText = address.slice(compression + 2);
    const left = leftText.length > 0 ? leftText.split(":") : [];
    const right = rightText.length > 0 ? rightText.split(":") : [];
    const units = ipv6UnitCount(left.concat(right));
    return units >= 0 && units < 8;
}

function partialIpv6Units(parts) {
    let units = 0;
    let incomplete = false;
    for (let index = 0; index < parts.length; ++index) {
        const part = parts[index];
        if (part.length === 0)
            return { valid: false, units: 0, incomplete: false };
        if (part.indexOf(".") >= 0) {
            if (index !== parts.length - 1)
                return { valid: false, units: 0, incomplete: false };
            const state = ipv4State(part);
            if (state === Invalid)
                return { valid: false, units: 0, incomplete: false };
            incomplete = state === Intermediate;
            units += 2;
        } else {
            if (!/^[0-9a-fA-F]{1,4}$/.test(part))
                return { valid: false, units: 0, incomplete: false };
            units += 1;
        }
    }
    return { valid: true, units: units, incomplete: incomplete };
}

function ipv6State(value) {
    const address = String(value || "").trim();
    if (address.length === 0 || address === ":")
        return Intermediate;
    if (isIpv6Complete(address))
        return Acceptable;
    if (!/^[0-9a-fA-F:.]+$/.test(address) || address.indexOf("%") >= 0 || address.indexOf(":::") >= 0)
        return Invalid;

    const compression = address.indexOf("::");
    if (compression >= 0 && address.indexOf("::", compression + 2) >= 0)
        return Invalid;
    if (compression < 0 && address[0] === ":")
        return Invalid;

    const trailingSeparator = address[address.length - 1] === ":" && !address.endsWith("::");
    const candidate = trailingSeparator ? address.slice(0, -1) : address;
    const candidateCompression = candidate.indexOf("::");
    let parts;
    if (candidateCompression >= 0) {
        const leftText = candidate.slice(0, candidateCompression);
        const rightText = candidate.slice(candidateCompression + 2);
        parts = (leftText.length > 0 ? leftText.split(":") : []).concat(rightText.length > 0 ? rightText.split(":") : []);
    } else {
        parts = candidate.split(":");
    }

    const result = partialIpv6Units(parts);
    if (!result.valid)
        return Invalid;
    if (candidateCompression >= 0)
        return result.units < 8 ? Intermediate : Invalid;
    if (result.units > 8 || (trailingSeparator && result.units >= 8))
        return Invalid;
    if (result.incomplete || result.units < 8)
        return Intermediate;
    return Invalid;
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

function addressInputState(value, family, multiple, allowEmpty) {
    const input = String(value || "").trim();
    if (input.length === 0)
        return allowEmpty ? Acceptable : Intermediate;
    if (!multiple)
        return addressState(input, family);
    if (input[0] === ",")
        return Invalid;

    const commaGroups = input.split(",");
    let finalState = Acceptable;
    for (let groupIndex = 0; groupIndex < commaGroups.length; ++groupIndex) {
        const group = commaGroups[groupIndex].trim();
        if (group.length === 0)
            return groupIndex === commaGroups.length - 1 ? Intermediate : Invalid;
        const addresses = group.split(/\s+/);
        for (let index = 0; index < addresses.length; ++index) {
            const state = addressState(addresses[index], family);
            const isLast = groupIndex === commaGroups.length - 1 && index === addresses.length - 1;
            if (state === Invalid || (!isLast && state !== Acceptable))
                return Invalid;
            if (isLast)
                finalState = state;
        }
    }
    return finalState;
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
