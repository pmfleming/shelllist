// Pure structured editor. The native input supplies selection/IME/clipboard text;
// this owner validates the entire operation before accepting a new local draft.
declare namespace Validation {
    const Invalid: number;
    const Intermediate: number;
    const Acceptable: number;
    function ipv4State(value: string): number;
    function ipv6State(value: string): number;
    function isIpv6Complete(value: string): boolean;
    function prefixState(value: string, family: string, allowEmpty: boolean): number;
}
interface IpConfiguration {
    family: string;
    mode: string;
    subnetNotation: string;
    allowEmpty: boolean;
}
interface IpPosition { text: string; cursor: number; anchor: number; autoSlot: number; }
interface IpComponent { start: number; end: number; value: string; kind: string; }
var MaximumDraftLength = 256; // Accepted edit operation, not a truncating native limit.

function combined(config: IpConfiguration): boolean { return config.mode === "addressWithSubnet"; }
function supported(config: IpConfiguration): boolean {
    return ["ipv4", "ipv6"].includes(config.family)
        && ["address", "addressWithSubnet"].includes(config.mode)
        && ["prefix", "netmask"].includes(config.subnetNotation)
        && !(config.family === "ipv6" && config.subnetNotation === "netmask");
}
function parts(value: string) { const pair = value.split("/"); return {address: pair[0], subnet: pair[1] || ""}; }
function maskPrefix(mask: string): number {
    if (Validation.ipv4State(mask) !== Validation.Acceptable) return -1;
    const bits = mask.split(".").map(part => Number(part).toString(2).padStart(8, "0")).join("");
    return /^1*0*$/.test(bits) ? bits.indexOf("0") < 0 ? 32 : bits.indexOf("0") : -1;
}
function prefixMask(prefix: number): string {
    if (!Number.isInteger(prefix) || prefix < 0 || prefix > 32) return "";
    return [0, 8, 16, 24].map(start => {
        const count = Math.max(0, Math.min(8, prefix - start));
        return String(256 - Math.pow(2, 8 - count));
    }).join(".");
}
function decimalAddress(address: string): string { return address.split(".").map(part => String(Number(part))).join("."); }
// Keep the IPv6 spelling (lowercase hex) rather than introducing a second
// compression algorithm. IPv4 tails still serialize strictly decimal.
function serializeAddress(address: string, family: string): string {
    if (family === "ipv4") return decimalAddress(address);
    const colon = address.lastIndexOf(":");
    return address.indexOf(".") >= 0
        ? address.slice(0, colon + 1).toLowerCase() + decimalAddress(address.slice(colon + 1))
        : address.toLowerCase();
}
function octetSlotsState(value: string): number {
    const slots = value.split(".");
    if (slots.length > 4 || slots.some(slot => slot.length > 0 && (!/^\d{1,3}$/.test(slot) || Number(slot) > 255)))
        return Validation.Invalid;
    return slots.length === 4 && slots.every(slot => slot.length > 0) ? Validation.Acceptable : Validation.Intermediate;
}
function inspectSubnet(value: string, config: IpConfiguration): {state: number; prefix: number | null} {
    if (!combined(config)) return {state: Validation.Acceptable, prefix: null};
    const mask = value.includes(".");
    const state = mask
        ? config.family === "ipv4" ? octetSlotsState(value) : Validation.Invalid
        : Validation.prefixState(value, config.family, false);
    if (state !== Validation.Acceptable) return {state, prefix: null};
    const prefix = mask ? maskPrefix(value) : Number(value);
    return {state: prefix < 0 ? Validation.Invalid : Validation.Acceptable, prefix};
}
function emptyPart(value: string, config: IpConfiguration): boolean { return value === "" || (config.family === "ipv4" && value === "..."); }
function inspectParts(value: string, pair: ReturnType<typeof parts>, config: IpConfiguration, empty: boolean): {state: number; prefix: number | null} {
    if (!supported(config) || value.length >= MaximumDraftLength || /\s/.test(value)
            || value.split("/").length > (combined(config) ? 2 : 1))
        return {state: Validation.Invalid, prefix: null};
    const addressState = config.family === "ipv4" ? octetSlotsState(pair.address) : Validation.ipv6State(pair.address);
    const subnet = inspectSubnet(pair.subnet, config);
    // Native ordering: either invalid half wins; both must be complete to save.
    const state = empty ? (config.allowEmpty ? Validation.Acceptable : Validation.Intermediate)
        : Math.min(addressState, subnet.state);
    return {state, prefix: subnet.prefix};
}
function inspect(value: string, config: IpConfiguration) {
    const pair = parts(value);
    const empty = emptyPart(pair.address, config) && (!combined(config) || emptyPart(pair.subnet, config));
    const result = inspectParts(value, pair, config, empty);
    const valid = result.state === Validation.Acceptable;
    const address = valid && !empty ? serializeAddress(pair.address, config.family) : pair.address;
    const subnet = valid && result.prefix !== null ? config.subnetNotation === "netmask" ? prefixMask(result.prefix) : String(result.prefix) : pair.subnet;
    let text = value;
    if (valid) text = empty ? "" : address + (combined(config) ? "/" + subnet : "");
    return {state: result.state, valid, empty, address: empty ? "" : address, prefixLength: empty ? null : result.prefix, text};
}
function padOctets(value: string): string {
    const slots = value.split(".");
    while (slots.length < 4) slots.push("");
    return slots.join(".");
}
function prepare(value: string, config: IpConfiguration): string {
    // Do not repair an unexpected source value or hide its suffix.
    if (!supported(config) || value.split("/").length > (combined(config) ? 2 : 1)) return value;
    const pair = parts(value);
    const address = config.family === "ipv4" ? padOctets(pair.address) : pair.address;
    if (!combined(config)) return address;
    // Retain pasted notation through the edit, including invalid masks.
    const mask = pair.subnet.includes(".") || (!pair.subnet && config.subnetNotation === "netmask");
    return address + "/" + (mask ? padOctets(pair.subnet) : pair.subnet);
}
function components(value: string, config: IpConfiguration): IpComponent[] {
    const pair = parts(value);
    let offset = 0;
    const result: IpComponent[] = [];
    function append(text: string, kind: string) {
        result.push({start: offset, end: offset + text.length, value: text, kind});
        offset += text.length + 1;
    }
    if (config.family === "ipv4") pair.address.split(".").forEach(slot => append(slot, "octet"));
    else append(pair.address, "ipv6");
    if (combined(config)) {
        if (pair.subnet.includes(".")) pair.subnet.split(".").forEach(slot => append(slot, "octet"));
        else append(pair.subnet, "prefix");
    }
    return result;
}
function joinComponents(slots: IpComponent[], values: string[], config: IpConfiguration): string {
    let text = "";
    slots.forEach((slot, index) => {
        if (index) text += index === (config.family === "ipv4" ? 4 : 1) ? "/" : ".";
        text += values[index];
    });
    return text;
}
function position(text: string, cursor: number, autoSlot = -1): IpPosition { return {text, cursor, anchor: cursor, autoSlot}; }
function separator(state: IpPosition, config: IpConfiguration, character: string): IpPosition | null {
    if (character === "/") {
        const slash = state.text.indexOf("/");
        return combined(config) && slash >= 0 ? position(state.text, slash + 1) : null;
    }
    const slots = components(state.text, config);
    const index = slots.findIndex(slot => state.cursor >= slot.start && state.cursor <= slot.end);
    if (index < 0 || slots[index].kind !== "octet" || index + 1 >= slots.length) return null;
    return position(state.text, slots[index + 1].start);
}
function fullPaste(value: string, config: IpConfiguration): string | null {
    if (!value || value.length >= MaximumDraftLength || !supported(config)) return null;
    // Spaces around the slash only; no trim-before-length or suffix stripping.
    const text = value.replace(/ *\/ */g, "/");
    if (/\s/.test(text) || text.split("/").length > (combined(config) ? 2 : 1)) return null;
    const pair = parts(text);
    const dotted = /^\d{1,3}(?:\.\d{1,3}){3}$/;
    if (config.family === "ipv4" ? !dotted.test(pair.address) : !Validation.isIpv6Complete(pair.address)) return null;
    if (text.includes("/") && !(/^\d{1,3}$/.test(pair.subnet) || (config.family === "ipv4" && dotted.test(pair.subnet)))) return null;
    // Bare full-address paste intentionally empties the old subnet.
    return prepare(text, config);
}
// undefined means a local edit; null means reject the entire full-value paste.
function pasteReplacement(config: IpConfiguration, insertion: string, paste: boolean, fullSelection: boolean): IpPosition | null | undefined {
    if (!(paste || fullSelection) || !/[.:/]/.test(insertion)) return undefined;
    const full = fullPaste(insertion, config);
    if (full !== null) return position(full, full.length);
    // Only IPv6 substring paste may fall through to local replacement.
    return fullSelection || config.family === "ipv4" || insertion.includes("/") ? null : undefined;
}
interface IpReplacementRange { start: number; end: number; index: number; }
function replacementRange(slots: IpComponent[], start: number, end: number, deleting: boolean, backwards: boolean): IpReplacementRange | null {
    const index = slots.findIndex(slot => start >= slot.start && start <= slot.end);
    if (index < 0) return null;
    if (!deleting || end <= start || slots.some(slot => start < slot.end && end > slot.start)) return {start, end, index};
    // Deleting only a fixed separator reaches the preceding/following digit.
    const adjacent = backwards
        ? slots.filter(slot => slot.end <= start && slot.value.length > 0).pop()
        : slots.find(slot => slot.start >= end && slot.value.length > 0);
    if (!adjacent) return null;
    const digit = backwards ? adjacent.end - 1 : adjacent.start;
    return {start: digit, end: digit + 1, index: slots.indexOf(adjacent)};
}
function slotOffset(slot: IpComponent, offset: number): number { return Math.max(0, Math.min(slot.value.length, offset - slot.start)); }
function replacementPosition(state: IpPosition, slots: IpComponent[], range: IpReplacementRange, insertion: string, paste: boolean, values: string[], text: string): IpPosition {
    const slot = slots[range.index];
    let cursor = range.start + insertion.length;
    let autoSlot = state.autoSlot;
    const fresh = !slot.value || (range.start <= slot.start && range.end >= slot.end);
    if (fresh && insertion) autoSlot = range.index;
    if (insertion.length !== 1 || paste || slot.kind !== "octet") autoSlot = -1;
    if (autoSlot === range.index && values[range.index].length === 3 && range.index + 1 < slots.length) {
        cursor++; autoSlot = -1;
    }
    return position(text, Math.min(cursor, text.length), autoSlot);
}
function replace(state: IpPosition, config: IpConfiguration, start: number, end: number,
        insertion: string, paste: boolean, backwards: boolean): IpPosition | null {
    if (!supported(config) || insertion.length >= MaximumDraftLength) return null;
    const fullSelection = start === 0 && end === state.text.length;
    const full = pasteReplacement(config, insertion, paste, fullSelection);
    if (full !== undefined) return full;
    const slots = components(state.text, config);
    // Unexpected source suffixes survive local edits. Only full replacement or
    // clear can recover the source, still through the same validated operation.
    if (joinComponents(slots, slots.map(slot => slot.value), config) !== state.text) {
        if (!fullSelection) return null;
        const blank = position(prepare("", config), 0);
        return replace(blank, config, 0, blank.text.length, insertion, paste, backwards);
    }
    const range = replacementRange(slots, start, end, !insertion, backwards);
    if (!range) return null;
    const slot = slots[range.index];
    if (!(slot.kind === "ipv6" ? /^[0-9a-fA-F:.]*$/ : /^\d*$/).test(insertion)) return null;
    const values = slots.map(part => part.value.slice(0, slotOffset(part, range.start))
        + part.value.slice(slotOffset(part, Math.max(range.start, range.end))));
    const local = slotOffset(slot, range.start);
    values[range.index] = values[range.index].slice(0, local) + insertion + values[range.index].slice(local);
    if (slot.kind !== "ipv6" && values[range.index].length > 3) return null;
    const text = joinComponents(slots, values, config);
    if (text.length >= MaximumDraftLength) return null;
    return replacementPosition(state, slots, range, insertion, paste, values, text);
}
// Native IME/clipboard/deletion may replace more than the current selection.
// Find its exact contiguous change without normalizing or clipping any text.
function nativeEdit(state: IpPosition, config: IpConfiguration, next: string, paste: boolean, backwards: boolean): IpPosition | null {
    let start = Math.min(state.cursor, state.anchor);
    let end = Math.max(state.cursor, state.anchor);
    let length = next.length - state.text.length + end - start;
    if (length < 0 || next.slice(0, start) !== state.text.slice(0, start)
            || next.slice(start + length) !== state.text.slice(end)) {
        start = 0;
        while (start < state.text.length && start < next.length && state.text[start] === next[start]) start++;
        end = state.text.length;
        let nextEnd = next.length;
        while (end > start && nextEnd > start && state.text[end - 1] === next[nextEnd - 1]) { end--; nextEnd--; }
        length = nextEnd - start;
    }
    const insertion = next.slice(start, start + length);
    return replace(state, config, start, end, insertion, paste, backwards);
}
