#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const [resourcesPath, fixturePath, modelPath] = process.argv.slice(2);
if (!resourcesPath || !fixturePath || !modelPath)
    throw new Error("usage: check-application-resources.js <ApplicationResources.js> <fixture.json> <app-daemon model.rs>");

const source = fs.readFileSync(resourcesPath, "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context, { filename: resourcesPath });

const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const model = fs.readFileSync(modelPath, "utf8");

function body(pattern, description) {
    const match = model.match(pattern);
    if (!match)
        throw new Error(`could not find ${description} in ${modelPath}`);
    return match[1];
}

function fields(structBody) {
    return [...structBody.matchAll(/^\s*(?:pub\s+)?([a-z][a-z0-9_]*)\s*:/gm)]
        .map(match => match[1]);
}

function usageFields(name) {
    return fields(body(new RegExp(`usage_fields!\\(${name}\\s*\\{([\\s\\S]*?)\\n\\}\\);`), name));
}

function structFields(name) {
    return fields(body(new RegExp(`pub struct ${name}\\s*\\{([\\s\\S]*?)\\n\\}`), name));
}

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

const compute = usageFields("ComputeUsage");
const storage = usageFields("StorageUsage");
const network = usageFields("NetworkUsage");
const energy = usageFields("EnergyUsage");
const measurement = structFields("ResourceMeasurement").map(key => `measurement.${key}`);
const currentExpected = [...compute, ...storage, ...network, ...energy, ...measurement];

const historicalDirect = structFields("HistoricalResourceUsage")
    .filter(key => !["compute", "storage", "network", "peaks"].includes(key));
const peaks = structFields("ResourcePeaks").map(key => `peaks.${key}`);
const historyExpected = ["timestamp_ms", "duration_ms", ...compute, ...storage, ...network,
    ...historicalDirect, ...peaks];

compare(leafPaths(fixture.current), currentExpected, "current fixture/backend model");
compare(detailKeys(fixture.current, false), currentExpected, "current UI/backend model");
compare(leafPaths(fixture.history_point), historyExpected, "history fixture/backend model");
compare(detailKeys(fixture.history_point, true), historyExpected, "history UI/backend model");

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
