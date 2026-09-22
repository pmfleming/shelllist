.pragma library

function internal(name) { return /^(eDP-|LVDS-|DSI-)/.test(name); }
function supported(name) { return /^(eDP-|LVDS-|DSI-|DP-|HDMI-A-)[A-Za-z0-9-]+$/.test(name) && name.length <= 64; }
function outputs(state) {
    return (state.outputs || []).filter(function (o) { return supported(o.name); }).slice().sort(function (a, b) {
        return Number(internal(b.name)) - Number(internal(a.name)) || a.name.localeCompare(b.name);
    });
}
function title(output) { return internal(output.name) ? "Laptop" : (output.description || output.name || ""); }
function parseMode(value) {
    const match = /^(\d+)x(\d+)@(\d+(?:\.\d+)?)(?:Hz)?$/.exec(String(value));
    if (!match) return null;
    const width = Number(match[1]), height = Number(match[2]), rate = Number(match[3]);
    return width > 0 && width <= 16384 && height > 0 && height <= 16384 && rate >= 1 && rate <= 1000
        ? { width: width, height: height, rate: rate, size: match[1] + "x" + match[2] } : null;
}
function currentMode(output) {
    const observed = output.width + "x" + output.height + "@" + Number(output.refreshRate).toFixed(2);
    const matching = (output.availableModes || []).filter(function (value) {
        const m = parseMode(value);
        return m && m.width === output.width && m.height === output.height && Math.abs(m.rate - output.refreshRate) < 0.1;
    });
    matching.sort(function (a, b) {
        return Math.abs(parseMode(a).rate - output.refreshRate) - Math.abs(parseMode(b).rate - output.refreshRate);
    });
    return matching[0] || observed;
}
function modes(output) {
    const values = (output.availableModes || []).filter(function (v) { return !!parseMode(v); });
    const current = currentMode(output);
    return values.includes(current) ? values : [current].concat(values);
}
function draft(outputs) {
    return outputs.map(function (o) {
        return { name: o.name, mode: currentMode(o), x: o.x || 0, y: o.y || 0, scale: o.scale,
            transform: o.transform || 0, enabled: internal(o.name) || !o.disabled };
    });
}
function topology(outputs) { return JSON.stringify(outputs.map(function (o) { return [o.name, o.id]; })); }
function fingerprint(outputs) {
    return JSON.stringify(outputs.map(function (o) { return [o.name, o.id, currentMode(o), o.scale, o.transform || 0, o.x || 0, o.y || 0, !!o.disabled, o.availableModes || []]; }));
}
function payload(draft) {
    return draft.map(function (d) {
        return { name: d.name, mode: d.mode, x: Number(d.x), y: Number(d.y), scale: Number(d.scale), transform: Number(d.transform), enabled: d.enabled };
    });
}
function number(value) { return String(value).trim().length > 0 && Number.isFinite(Number(value)); }
function validate(draft, outputs) {
    if (!draft.length || draft.length > 16) return "Connect between one and sixteen supported displays";
    if (draft.length !== outputs.length) return "Displays changed · reload the layout";
    const seen = [];
    for (const d of draft) {
        const o = outputs.find(function (v) { return v.name === d.name; });
        if (!o || seen.includes(d.name)) return "Displays changed · reload the layout";
        seen.push(d.name);
        if (!number(d.x) || !number(d.y) || !Number.isInteger(Number(d.x)) || !Number.isInteger(Number(d.y)) || Math.abs(Number(d.x)) > 32768 || Math.abs(Number(d.y)) > 32768)
            return "Position must be a whole number between −32768 and 32768";
        if (!number(d.scale) || Number(d.scale) < 0.5 || Number(d.scale) > 4) return "Scale must be between 50% and 400%";
        if (!number(d.transform) || !Number.isInteger(Number(d.transform)) || Number(d.transform) < 0 || Number(d.transform) > 7) return "Choose a supported rotation";
        if (typeof d.enabled !== "boolean" || (internal(d.name) && !d.enabled)) return "Laptop fallback is managed by the external-display preference";
        const m = parseMode(d.mode);
        if (!m || m.width < 1 || m.height < 1 || m.width > 16384 || m.height > 16384 || m.rate < 1 || m.rate > 1000 || (d.enabled && !modes(o).includes(d.mode))) return "Choose an advertised display mode";
    }
    return draft.some(function (d) { return d.enabled; }) ? "" : "Keep at least one display enabled";
}
function rect(output) {
    const m = parseMode(output.mode) || { width: output.width || 1, height: output.height || 1 };
    const scale = number(output.scale) && Number(output.scale) > 0 ? Number(output.scale) : 1;
    const rotated = Number(output.transform || 0) % 2 === 1;
    return { x: number(output.x) ? Number(output.x) : 0, y: number(output.y) ? Number(output.y) : 0,
        width: (rotated ? m.height : m.width) / scale, height: (rotated ? m.width : m.height) / scale };
}
function bounds(values) {
    if (!values.length) return { x: 0, y: 0, width: 1920, height: 1080 };
    const r = values.map(rect);
    const x = Math.min.apply(null, r.map(function (v) { return v.x; }));
    const y = Math.min.apply(null, r.map(function (v) { return v.y; }));
    return { x: x, y: y, width: Math.max(1, Math.max.apply(null, r.map(function (v) { return v.x + v.width; })) - x),
        height: Math.max(1, Math.max.apply(null, r.map(function (v) { return v.y + v.height; })) - y) };
}
function snap(values, name, x, y, threshold) {
    const own = values.find(function (o) { return o.name === name; });
    if (!own) return { x: x, y: y };
    const r = rect(own);
    let bestX = threshold, bestY = threshold, result = { x: x, y: y };
    for (const o of values) {
        if (o.name === name || o.enabled === false) continue;
        const other = rect(o);
        for (const edge of [other.x, other.x + other.width]) {
            for (const offset of [0, r.width]) {
                const distance = Math.abs(edge - offset - x);
                if (distance < bestX) { bestX = distance; result.x = edge - offset; }
            }
        }
        for (const edge of [other.y, other.y + other.height]) {
            for (const offset of [0, r.height]) {
                const distance = Math.abs(edge - offset - y);
                if (distance < bestY) { bestY = distance; result.y = edge - offset; }
            }
        }
    }
    return result;
}
function adjacent(selected, reference, side) {
    const r = rect(reference), own = rect(selected);
    return { x: side === "left" ? r.x - own.width : side === "right" ? r.x + r.width : r.x,
        y: side === "above" ? r.y - own.height : side === "below" ? r.y + r.height : r.y };
}
function resolutions(output) {
    const seen = [];
    return modes(output).map(parseMode).filter(function (m) {
        if (!m || seen.includes(m.size)) return false;
        seen.push(m.size); return true;
    }).map(function (m) { return { value: m.size, label: m.width + " × " + m.height }; });
}
function rates(output, mode) {
    const size = (parseMode(mode) || {}).size;
    return modes(output).filter(function (v) { const parsed = parseMode(v); return parsed && parsed.size === size; })
        .map(function (v) { return { value: v, label: parseMode(v).rate + " Hz" }; });
}
