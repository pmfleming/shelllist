.pragma library

function outputs(state) {
    return (state.outputs || []).filter(o => o.supported === true).sort((a, b) => Number(b.internal) - Number(a.internal) || a.name.localeCompare(b.name));
}
function title(output) {
    return output.internal ? "Laptop" : (output.description || output.name || "");
}
// The laptop panel was switched off because the policy prefers an external display.
function dockedOff(output, policyState) {
    return output.disabled && output.internal && policyState.available && policyState.status === "external" && !!(policyState.policy || {}).prefer_external;
}
function modeSummary(output) {
    return output.width > 0 && output.height > 0 ? output.width + "×" + output.height + " · " + Number(output.refreshRate).toFixed(2) + " Hz" : "";
}
// IDs are opaque daemon values. Geometry comes from the same snapshot's typed
// mode catalog, never from reparsing the compositor's availableModes strings.
function modes(output) {
    return output.modes || [];
}
function modeInfo(output, id) {
    const selected = id === undefined ? (output.mode || output.current_mode) : id;
    return modes(output).find(m => m.id === selected) || null;
}
function mirrorSource(output) {
    return output.mirror_of || "";
}
function isIndependent(output) {
    return output.enabled && !output.mirror_of;
}
function mirrorSources(draft, name) {
    // A source with dependents must remain independent; no chains or cycles.
    if (draft.some(o => o.enabled && o.mirror_of === name))
        return [];
    return draft.filter(o => o.name !== name && isIndependent(o));
}
function extend(draft, name) {
    const own = draft.find(o => o.name === name);
    if (!own || !own.mirror_of)
        return draft;
    const others = draft.filter(o => o.name !== name && isIndependent(o));
    const right = others.length ? Math.max(...others.map(o => rect(o).x + rect(o).width)) : Number(own.x);
    return draft.map(o => o.name === name ? Object.assign({}, o, {
            mirror_of: "",
            x: Math.round(right)
        }) : o);
}
function setEnabled(draft, name, enabled) {
    let next = draft.map(o => o.name === name ? Object.assign({}, o, {
            enabled: enabled,
            mirror_of: enabled ? (o.mirror_of || "") : ""
        }) : o);
    if (!enabled) {
        // Promote the mirrors before their source is disabled by the daemon.
        for (const mirror of next.filter(o => o.enabled && o.mirror_of === name))
            next = extend(next, mirror.name);
    }
    return next;
}
function draft(outputs) {
    return outputs.map(function (o) {
        return {
            name: o.name,
            mode: o.current_mode || "",
            modes: modes(o),
            internal: !!o.internal,
            width: o.width,
            height: o.height,
            x: o.x || 0,
            y: o.y || 0,
            scale: o.scale,
            transform: o.transform || 0,
            enabled: !o.disabled,
            mirror_of: mirrorSource(o)
        };
    });
}
function topology(outputs) {
    return JSON.stringify(outputs.map(o => [o.name, o.id]));
}
function fingerprint(outputs) {
    return JSON.stringify(outputs.map(o => [o.name, o.id, o.current_mode, o.scale, o.transform || 0, o.x || 0, o.y || 0, !!o.disabled, mirrorSource(o), modes(o)]));
}
function payload(draft) {
    return draft.map(function (d) {
        return {
            name: d.name,
            mode: d.mode,
            x: Number(d.x),
            y: Number(d.y),
            scale: Number(d.scale),
            transform: Number(d.transform),
            enabled: d.enabled,
            mirror_of: d.mirror_of || ""
        };
    });
}
function number(value) {
    return String(value).trim().length > 0 && Number.isFinite(Number(value));
}
function inRange(value, minimum, maximum, whole) {
    return number(value) && Number(value) >= minimum && Number(value) <= maximum && (!whole || Number.isInteger(Number(value)));
}
function validateOutput(d, output, draft) {
    if (!inRange(d.x, -32768, 32768, true) || !inRange(d.y, -32768, 32768, true))
        return "Position must be a whole number between −32768 and 32768";
    if (!inRange(d.scale, 0.5, 4, false))
        return "Scale must be between 50% and 400%";
    if (!inRange(d.transform, 0, 7, true))
        return "Choose a supported rotation";
    if (typeof d.enabled !== "boolean")
        return "Choose whether this display is enabled";
    if (d.mirror_of !== undefined && typeof d.mirror_of !== "string")
        return "Choose a supported mirror source";
    const source = d.mirror_of || "";
    if (source && (!draft.some(v => v.name === source) || source === d.name))
        return "Choose a different supported display to mirror";
    if (d.enabled && source && !draft.some(v => v.name === source && isIndependent(v)))
        return "Mirror source must be an enabled extended display";
    if (!modeInfo(output, d.mode))
        return "Choose an advertised display mode";
    return "";
}
function validate(draft, outputs) {
    if (!draft.length || draft.length > 16)
        return "Connect between one and sixteen supported displays";
    if (draft.length !== outputs.length)
        return "Displays changed · reload the layout";
    const seen = [];
    for (const d of draft) {
        const output = outputs.find(v => v.name === d.name);
        if (!output || seen.includes(d.name))
            return "Displays changed · reload the layout";
        seen.push(d.name);
        const error = validateOutput(d, output, draft);
        if (error)
            return error;
    }
    return draft.some(isIndependent) ? "" : "Keep at least one independent display enabled";
}
function rect(output) {
    const m = modeInfo(output) || {
        width: output.width || 1,
        height: output.height || 1
    };
    const scale = number(output.scale) && Number(output.scale) > 0 ? Number(output.scale) : 1;
    const rotated = Number(output.transform || 0) % 2 === 1;
    return {
        x: number(output.x) ? Number(output.x) : 0,
        y: number(output.y) ? Number(output.y) : 0,
        width: (rotated ? m.height : m.width) / scale,
        height: (rotated ? m.width : m.height) / scale
    };
}
function bounds(values) {
    if (!values.length)
        return {
            x: 0,
            y: 0,
            width: 1920,
            height: 1080
        };
    const r = values.map(rect);
    const x = Math.min(...r.map(v => v.x));
    const y = Math.min(...r.map(v => v.y));
    return {
        x: x,
        y: y,
        width: Math.max(1, Math.max(...r.map(v => v.x + v.width)) - x),
        height: Math.max(1, Math.max(...r.map(v => v.y + v.height)) - y)
    };
}
// Disabled outputs and mirrors have no independent desktop position. Park them
// beside the desktop in the diagram so an overlapping (often 0,0) coordinate
// cannot hide a connected screen. These presentation coordinates never persist.
function canvasValues(draft) {
    const independent = draft.filter(isIndependent);
    const extent = bounds(independent);
    const gap = Math.max(80, extent.width * 0.04);
    let x = independent.length ? extent.x + extent.width + gap : 0;
    return draft.map(function (output) {
        if (isIndependent(output))
            return output;
        const tile = Object.assign({}, output, { x: x, y: independent.length ? extent.y : 0 });
        x += rect(output).width + gap;
        return tile;
    });
}
function placementRect(output) {
    const r = rect(output);
    // Positions use integer logical pixels at the daemon boundary. Use the same
    // rounded extents for adjacency and collision checks (not subpixel overlap).
    return { x: Math.round(r.x), y: Math.round(r.y), width: Math.max(1, Math.round(r.width)), height: Math.max(1, Math.round(r.height)) };
}
function overlaps(a, b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}
function placementReferences(values, name) {
    return values.filter(o => o.name !== name && isIndependent(o));
}
function adjacent(selected, reference, side) {
    const r = placementRect(reference), own = placementRect(selected);
    return {
        x: side === "left" ? r.x - own.width : side === "right" ? r.x + r.width : r.x,
        y: side === "above" ? r.y - own.height : side === "below" ? r.y + r.height : r.y
    };
}
function placement(values, name, referenceName, side) {
    const selected = values.find(o => o.name === name);
    const reference = values.find(o => o.name === referenceName);
    if (!selected || !isIndependent(selected))
        return { error: "Select an enabled extended display" };
    if (!reference || reference === selected || !isIndependent(reference))
        return { error: "Choose another enabled extended display" };
    if (!["left", "above", "below", "right"].includes(side))
        return { error: "Choose a side of the reference display" };
    const position = adjacent(selected, reference, side);
    const candidate = Object.assign({}, placementRect(selected), position, { name: name, reference: referenceName, side: side, error: "" });
    if (!inRange(position.x, -32768, 32768, true) || !inRange(position.y, -32768, 32768, true))
        candidate.error = "Position exceeds supported coordinates";
    else {
        const collision = values.find(o => o.name !== name && isIndependent(o) && overlaps(candidate, placementRect(o)));
        if (collision)
            candidate.error = "Would overlap " + collision.name;
    }
    return candidate;
}
// Keep observed layouts intact; only changed geometry must pass the new overlap
// guard. This also catches mode/scale/rotation changes after a valid placement.
function arrangementError(values, baseline) {
    const independent = values.filter(isIndependent);
    for (let i = 0; i < independent.length; ++i) {
        for (let j = i + 1; j < independent.length; ++j) {
            const a = independent[i], b = independent[j];
            if (!overlaps(placementRect(a), placementRect(b)))
                continue;
            const oldA = baseline.find(o => o.name === a.name && isIndependent(o));
            const oldB = baseline.find(o => o.name === b.name && isIndependent(o));
            if (!oldA || !oldB || JSON.stringify(placementRect(a)) !== JSON.stringify(placementRect(oldA)) || JSON.stringify(placementRect(b)) !== JSON.stringify(placementRect(oldB)))
                return a.name + " overlaps " + b.name + " · arrange displays before previewing";
        }
    }
    return "";
}
// Hit-test edge segments, not the old tile's free coordinates. Hysteresis keeps
// the current side stable near corners; distant/outside drops have no target.
function dropTarget(values, name, x, y, threshold, previous, hysteresis) {
    const edges = [];
    for (const output of placementReferences(values, name)) {
        const r = placementRect(output);
        const dx = x - Math.max(r.x, Math.min(x, r.x + r.width));
        const dy = y - Math.max(r.y, Math.min(y, r.y + r.height));
        for (const [side, distance] of [
            ["left", Math.hypot(x - r.x, dy)],
            ["above", Math.hypot(dx, y - r.y)],
            ["below", Math.hypot(dx, y - (r.y + r.height))],
            ["right", Math.hypot(x - (r.x + r.width), dy)]
        ]) {
            if (distance <= threshold)
                edges.push({ reference: output.name, side: side, distance: distance, inside: x > r.x && x < r.x + r.width && y > r.y && y < r.y + r.height });
        }
    }
    // On a shared edge, moving just inside a tile unambiguously chooses it as
    // the reference instead of sticking to its neighbour through hysteresis.
    const candidates = edges.some(e => e.inside) ? edges.filter(e => e.inside) : edges;
    candidates.sort((a, b) => a.distance - b.distance);
    if (!candidates.length)
        return null;
    const retained = previous && candidates.find(e => e.reference === previous.reference && e.side === previous.side);
    return retained && retained.distance <= candidates[0].distance + hysteresis ? retained : candidates[0];
}
function dragBounds(values, name) {
    const selected = values.find(o => o.name === name);
    const tiles = canvasValues(values);
    if (selected && isIndependent(selected)) {
        for (const reference of placementReferences(values, name)) {
            for (const side of ["left", "above", "below", "right"])
                tiles.push(Object.assign({}, selected, adjacent(selected, reference, side)));
        }
    }
    return bounds(tiles);
}
function resolutions(output) {
    const seen = [];
    return modes(output).filter(function (m) {
        if (!m || seen.includes(m.size))
            return false;
        seen.push(m.size);
        return true;
    }).map(function (m) {
        return {
            value: m.size,
            label: m.width + " × " + m.height
        };
    });
}
function rates(output, mode) {
    const size = (modeInfo(output, mode) || {}).size;
    return modes(output).filter(m => m.size === size).map(function (m) {
        return {
            value: m.id,
            label: m.rate + " Hz"
        };
    });
}
