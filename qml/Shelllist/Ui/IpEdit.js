.pragma library
.import "IpValidation.js" as Validation

"use strict";
var MaximumDraftLength = 256; // Accepted edit operation, not a truncating native limit.
function combined(config) { return config.mode === "addressWithSubnet"; }
function supported(config) {
    return ["ipv4", "ipv6"].includes(config.family)
        && ["address", "addressWithSubnet"].includes(config.mode)
        && ["prefix", "netmask"].includes(config.subnetNotation)
        && !(config.family === "ipv6" && config.subnetNotation === "netmask");
}
function parts(value) { const pair = value.split("/"); return { address: pair[0], subnet: pair[1] || "" }; }
function maskPrefix(mask) {
    if (Validation.ipv4State(mask) !== Validation.Acceptable)
        return -1;
    const bits = mask.split(".").map(part => Number(part).toString(2).padStart(8, "0")).join("");
    return /^1*0*$/.test(bits) ? bits.indexOf("0") < 0 ? 32 : bits.indexOf("0") : -1;
}
function prefixMask(prefix) {
    if (!Number.isInteger(prefix) || prefix < 0 || prefix > 32)
        return "";
    return [0, 8, 16, 24].map(start => {
        const count = Math.max(0, Math.min(8, prefix - start));
        return String(256 - Math.pow(2, 8 - count));
    }).join(".");
}
function decimalAddress(address) { return address.split(".").map(part => String(Number(part))).join("."); }
// Keep the IPv6 spelling (lowercase hex) rather than introducing a second
// compression algorithm. IPv4 tails still serialize strictly decimal.
function serializeAddress(address, family) {
    if (family === "ipv4")
        return decimalAddress(address);
    const colon = address.lastIndexOf(":");
    return address.indexOf(".") >= 0
        ? address.slice(0, colon + 1).toLowerCase() + decimalAddress(address.slice(colon + 1))
        : address.toLowerCase();
}
function octetSlotsState(value) {
    const slots = value.split(".");
    if (slots.length > 4 || slots.some(slot => slot.length > 0 && (!/^\d{1,3}$/.test(slot) || Number(slot) > 255)))
        return Validation.Invalid;
    return slots.length === 4 && slots.every(slot => slot.length > 0) ? Validation.Acceptable : Validation.Intermediate;
}
function inspect(value, config) {
    const pair = parts(value);
    const emptyAddress = pair.address === "" || (config.family === "ipv4" && pair.address === "...");
    const emptySubnet = pair.subnet === "" || (config.family === "ipv4" && pair.subnet === "...");
    const empty = emptyAddress && (!combined(config) || emptySubnet);
    let state = Validation.Invalid;
    let prefix = null;
    if (supported(config) && value.length < MaximumDraftLength && !/\s/.test(value)
        && value.split("/").length <= (combined(config) ? 2 : 1)) {
        const addressState = config.family === "ipv4" ? octetSlotsState(pair.address) : Validation.ipv6State(pair.address);
        let subnetState = Validation.Acceptable;
        if (combined(config)) {
            if (pair.subnet.includes(".")) {
                subnetState = config.family === "ipv4" ? octetSlotsState(pair.subnet) : Validation.Invalid;
                if (subnetState === Validation.Acceptable) {
                    prefix = maskPrefix(pair.subnet);
                    if (prefix < 0)
                        subnetState = Validation.Invalid;
                }
            }
            else {
                subnetState = Validation.prefixState(pair.subnet, config.family, false);
                if (subnetState === Validation.Acceptable)
                    prefix = Number(pair.subnet);
            }
        }
        state = addressState === Validation.Invalid || subnetState === Validation.Invalid ? Validation.Invalid
            : addressState === Validation.Intermediate || subnetState === Validation.Intermediate ? Validation.Intermediate : Validation.Acceptable;
        if (empty)
            state = config.allowEmpty ? Validation.Acceptable : Validation.Intermediate;
    }
    const valid = state === Validation.Acceptable;
    const address = valid && !empty ? serializeAddress(pair.address, config.family) : pair.address;
    const subnet = valid && prefix !== null ? config.subnetNotation === "netmask" ? prefixMask(prefix) : String(prefix) : pair.subnet;
    const text = valid ? empty ? "" : address + (combined(config) ? "/" + subnet : "") : value;
    return { state, valid, empty, address: empty ? "" : address, prefixLength: empty ? null : prefix, text };
}
function padOctets(value) {
    const slots = value.split(".");
    while (slots.length < 4)
        slots.push("");
    return slots.join(".");
}
function prepare(value, config) {
    // Do not repair an unexpected source value or hide its suffix.
    if (!supported(config) || value.split("/").length > (combined(config) ? 2 : 1))
        return value;
    const pair = parts(value);
    const address = config.family === "ipv4" ? padOctets(pair.address) : pair.address;
    if (!combined(config))
        return address;
    // Retain pasted notation through the edit, including invalid masks.
    const mask = pair.subnet.includes(".") || (!pair.subnet && config.subnetNotation === "netmask");
    return address + "/" + (mask ? padOctets(pair.subnet) : pair.subnet);
}
function components(value, config) {
    const pair = parts(value);
    let offset = 0;
    const result = [];
    function append(text, kind) {
        result.push({ start: offset, end: offset + text.length, value: text, kind });
        offset += text.length + 1;
    }
    if (config.family === "ipv4")
        pair.address.split(".").forEach(slot => append(slot, "octet"));
    else
        append(pair.address, "ipv6");
    if (combined(config)) {
        if (pair.subnet.includes("."))
            pair.subnet.split(".").forEach(slot => append(slot, "octet"));
        else
            append(pair.subnet, "prefix");
    }
    return result;
}
function joinComponents(slots, values, config) {
    let text = "";
    slots.forEach((slot, index) => {
        if (index)
            text += index === (config.family === "ipv4" ? 4 : 1) ? "/" : ".";
        text += values[index];
    });
    return text;
}
function position(text, cursor, autoSlot = -1) { return { text, cursor, anchor: cursor, autoSlot }; }
function separator(state, config, character) {
    if (character === "/") {
        const slash = state.text.indexOf("/");
        return combined(config) && slash >= 0 ? position(state.text, slash + 1) : null;
    }
    const slots = components(state.text, config);
    const index = slots.findIndex(slot => state.cursor >= slot.start && state.cursor <= slot.end);
    if (index < 0 || slots[index].kind !== "octet" || index + 1 >= slots.length)
        return null;
    return position(state.text, slots[index + 1].start);
}
function fullPaste(value, config) {
    if (!value || value.length >= MaximumDraftLength || !supported(config))
        return null;
    // Spaces around the slash only; no trim-before-length or suffix stripping.
    const text = value.replace(/ *\/ */g, "/");
    if (/\s/.test(text) || text.split("/").length > (combined(config) ? 2 : 1))
        return null;
    const pair = parts(text);
    const dotted = /^\d{1,3}(?:\.\d{1,3}){3}$/;
    if (config.family === "ipv4" ? !dotted.test(pair.address) : !Validation.isIpv6Complete(pair.address))
        return null;
    if (text.includes("/") && !(/^\d{1,3}$/.test(pair.subnet) || (config.family === "ipv4" && dotted.test(pair.subnet))))
        return null;
    // Bare full-address paste intentionally empties the old subnet.
    return prepare(text, config);
}
function replace(state, config, start, end, insertion, paste, backwards) {
    if (!supported(config) || insertion.length >= MaximumDraftLength)
        return null;
    const fullSelection = start === 0 && end === state.text.length;
    if ((paste || fullSelection) && /[.:/]/.test(insertion)) {
        const full = fullPaste(insertion, config);
        if (full !== null)
            return position(full, full.length);
        // IPv6 substring paste uses ordinary selection replacement; a full-value
        // malformed paste must never fall through and salvage a substring.
        if (fullSelection || config.family === "ipv4" || insertion.includes("/"))
            return null;
    }
    const slots = components(state.text, config);
    // An unexpected bound source must not lose unrepresented suffixes while
    // editing. Full replacement/clear is still available for recovery.
    if (joinComponents(slots, slots.map(slot => slot.value), config) !== state.text) {
        if (!fullSelection)
            return null;
        const blank = position(prepare("", config), 0);
        return replace(blank, config, 0, blank.text.length, insertion, paste, backwards);
    }
    let index = slots.findIndex(slot => start >= slot.start && start <= slot.end);
    if (index < 0)
        return null;
    // Deleting only a fixed separator reaches the preceding/following digit.
    if (!insertion && end > start && !slots.some(slot => start < slot.end && end > slot.start)) {
        if (backwards) {
            const previous = slots.filter(slot => slot.end <= start && slot.value.length > 0).pop();
            if (!previous)
                return null;
            start = previous.end - 1;
            end = previous.end;
        }
        else {
            const next = slots.find(slot => slot.start >= end && slot.value.length > 0);
            if (!next)
                return null;
            start = next.start;
            end = next.start + 1;
        }
        index = slots.findIndex(slot => start >= slot.start && start < slot.end);
    }
    const slot = slots[index];
    if (!(slot.kind === "ipv6" ? /^[0-9a-fA-F:.]*$/ : /^\d*$/).test(insertion))
        return null;
    const values = slots.map(part => {
        const left = Math.max(0, Math.min(part.value.length, start - part.start));
        const right = Math.max(left, Math.min(part.value.length, end - part.start));
        return part.value.slice(0, left) + part.value.slice(right);
    });
    const local = Math.max(0, Math.min(slot.value.length, start - slot.start));
    values[index] = values[index].slice(0, local) + insertion + values[index].slice(local);
    if (slot.kind !== "ipv6" && values[index].length > 3)
        return null;
    const text = joinComponents(slots, values, config);
    if (text.length >= MaximumDraftLength)
        return null;
    let cursor = start + insertion.length;
    let autoSlot = state.autoSlot;
    const fresh = !slot.value || (start <= slot.start && end >= slot.end);
    if (fresh && insertion)
        autoSlot = index;
    if (!insertion || insertion.length > 1 || paste || slot.kind !== "octet")
        autoSlot = -1;
    if (autoSlot === index && values[index].length === 3 && index + 1 < slots.length) {
        cursor++;
        autoSlot = -1;
    }
    return position(text, Math.min(cursor, text.length), autoSlot);
}
// Native IME/clipboard/deletion may replace more than the current selection.
// Find its exact contiguous change without normalizing or clipping any text.
function nativeEdit(state, config, next, paste, backwards) {
    let start = Math.min(state.cursor, state.anchor);
    let end = Math.max(state.cursor, state.anchor);
    let length = next.length - state.text.length + end - start;
    if (length < 0 || next.slice(0, start) !== state.text.slice(0, start)
        || next.slice(start + length) !== state.text.slice(end)) {
        start = 0;
        while (start < state.text.length && start < next.length && state.text[start] === next[start])
            start++;
        end = state.text.length;
        let nextEnd = next.length;
        while (end > start && nextEnd > start && state.text[end - 1] === next[nextEnd - 1]) {
            end--;
            nextEnd--;
        }
        length = nextEnd - start;
    }
    const insertion = next.slice(start, start + length);
    return replace(state, config, start, end, insertion, paste, backwards);
}
