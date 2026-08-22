#!/usr/bin/env node
const fs = require("fs");

const projectRoot = process.argv[2];
if (!projectRoot)
    throw new Error("project root argument is required");

const componentPath = `${projectRoot}/qml/Shelllist/Ui/list/ScrollableListView.qml`;
const component = fs.readFileSync(componentPath, "utf8");
for (const token of ["ListView", "Flickable.StopAtBounds",
    "Flickable.VerticalFlick", "interactive: true"])
    if (!component.includes(token))
        throw new Error(`ScrollableListView is missing contract token: ${token}`);

function qmlFiles(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
        const child = `${directory}/${entry.name}`;
        if (entry.isDirectory() && ![".git", "target"].includes(entry.name))
            return qmlFiles(child);
        return entry.isFile() && entry.name.endsWith(".qml") ? [child] : [];
    });
}

const rawListView = /(^|[^A-Za-z0-9_])ListView\s*\{/m;
const violations = qmlFiles(projectRoot).filter(file =>
    file !== componentPath && rawListView.test(fs.readFileSync(file, "utf8")));
if (violations.length > 0)
    throw new Error(`lists bypass ScrollableListView:\n${violations.join("\n")}`);

const stateLayer = fs.readFileSync(
    `${projectRoot}/qml/Shelllist/Ui/StateLayer.qml`, "utf8");
for (const token of ["property bool consumeWheel: false",
    "event.accepted = root.consumeWheel"])
    if (!stateLayer.includes(token))
        throw new Error(`StateLayer is missing wheel pass-through token: ${token}`);

for (const relative of ["bar/BarAction.qml", "bar/BarTrayItem.qml"]) {
    const source = fs.readFileSync(`${projectRoot}/${relative}`, "utf8");
    if (!source.includes("consumeWheel: true"))
        throw new Error(`${relative} must explicitly consume its action wheel events`);
}

console.log("list scroll contract checks passed");
