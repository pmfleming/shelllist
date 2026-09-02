#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const vm = require("vm");
const { performance } = require("perf_hooks");

const [modelPath, outputPath] = process.argv.slice(2);
if (!modelPath || !outputPath)
    throw new Error("usage: generate-performance-benchmarks.js <Model.js> <output.json>");

const source = fs.readFileSync(modelPath, "utf8").replace(/^\.pragma library\s*$/m, "");
const model = {};
vm.createContext(model);
vm.runInContext(source, model, { filename: modelPath });

function percentile(values, fraction) {
    const sorted = values.slice().sort((left, right) => left - right);
    return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))];
}

function benchmark(operation, operationsPerSample, sampleCount = 12) {
    for (let index = 0; index < 3; index++)
        operation();
    const results = [];
    for (let sample = 0; sample < sampleCount; sample++) {
        const started = performance.now();
        for (let iteration = 0; iteration < operationsPerSample; iteration++)
            operation();
        const elapsedSeconds = Math.max(0.000001, (performance.now() - started) / 1000);
        results.push(operationsPerSample / elapsedSeconds);
    }
    const average = results.reduce((sum, value) => sum + value, 0) / results.length;
    const variance = results.reduce((sum, value) => sum + (value - average) ** 2, 0)
        / results.length;
    const standardDeviation = Math.sqrt(variance);
    return {
        average,
        median: percentile(results, 0.5),
        "samples-in-average": results.length,
        "standard-deviation": standardDeviation,
        "coefficient-of-variation": standardDeviation / average,
        results
    };
}

const rawResults = Array.from({ length: 1000 }, (_, index) => ({
    providerId: "applications",
    providerPriority: index % 3,
    id: `app-${index}`,
    title: index % 7 === 0 ? `Terminal ${index}` : `Application ${index}`,
    subtitle: `Desktop application number ${index}`,
    keywords: [`app${index}`, index % 2 === 0 ? "utility" : "desktop"],
    score: 1000 - index,
    actions: []
}));
const normalized = model.resultList(rawResults);

const qtVersion = process.env.QT_VERSION || "qt6";

const report = {
    id: "shelllist-policy-benchmarks-v1",
    qt: qtVersion,
    os: `${os.platform()}-${os.arch()}`,
    opengl: "not-applicable",
    windowSize: "headless",
    "command-line": process.argv.join(" "),
    "normalize-1000-results-per-second": benchmark(
        () => model.resultList(rawResults), 10),
    "rank-empty-1000-results-per-second": benchmark(
        () => model.rankResults(normalized, ""), 20),
    "rank-filter-1000-results-per-second": benchmark(
        () => model.rankResults(normalized, "terminal 9"), 10)
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, JSON.stringify(report, null, 2) + "\n");
console.log(`performance benchmarks written to ${outputPath}`);
