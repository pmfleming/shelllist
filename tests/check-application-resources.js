#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const [resourcesPath, fixturePath] = process.argv.slice(2);
if (!resourcesPath || !fixturePath)
    throw new Error("usage: check-application-resources.js <ApplicationResources.js> <fixture.json>");

const source = fs.readFileSync(resourcesPath, "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: resourcesPath });

const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));

function leafPaths(value, prefix = "") {
    return Object.entries(value).flatMap(([key, child]) => {
        const path = prefix ? `${prefix}.${key}` : key;
        return child !== null && typeof child === "object" && !Array.isArray(child)
            ? leafPaths(child, path) : [path];
    });
}

function detailKeys(resource, historical) {
    return context.detailGroups(resource, historical)
        .flatMap(group => group.fields.map(field => field.key));
}

function compare(actual, expected, description) {
    const actualSet = new Set(actual);
    const expectedSet = new Set(expected);
    const missing = [...expectedSet].filter(key => !actualSet.has(key));
    const unexpected = [...actualSet].filter(key => !expectedSet.has(key));
    if (missing.length || unexpected.length) {
        throw new Error(`${description} mismatch\nmissing: ${missing.join(", ") || "none"}\nunexpected: ${unexpected.join(", ") || "none"}`);
    }
    if (actual.length !== actualSet.size)
        throw new Error(`${description} contains duplicate field dispositions`);
}

// The daemon owns this wire fixture and tests it against the serialized Rust
// model. This check deliberately consumes only that public contract instead of
// parsing private Rust source layout.
const currentExpected = leafPaths(fixture.current);
const historyExpected = leafPaths(fixture.history_point);

compare(detailKeys(fixture.current, false), currentExpected, "current UI/wire contract");
compare(detailKeys(fixture.history_point, true), historyExpected, "history UI/wire contract");

const unavailableNetwork = Object.assign({}, fixture.current, {
    measurement: Object.assign({}, fixture.current.measurement, { network_bytes_available: false })
});
const capabilityFields = new Map(detailKeys(unavailableNetwork, false).map(key => [key, true]));
if (!capabilityFields.has("measurement.network_bytes_available"))
    throw new Error("unsupported network byte accounting is not presented");
if (!context.metadataBadges(Object.assign({ running: true }, fixture.current), null)
        .some(badge => badge.text.includes("coverage")))
    throw new Error("measurement provenance badges omit coverage");
if (!context.metadataBadges({ running: false }, fixture.history_point)
        .some(badge => badge.text === "Retained history"))
    throw new Error("retained history provenance is not presented");

console.log(`application resources: ${currentExpected.length} current and ${historyExpected.length} historical fields covered`);
