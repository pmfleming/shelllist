#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const apiPath = process.argv[2];
if (!apiPath)
    throw new Error("usage: check-clipboard-actions.js <ClipApi.js>");
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(apiPath, "utf8").replace(/^\.pragma library\s*/, ""), context);

function expect(kind, expected) {
    const actual = context.actionsForKind(kind);
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${kind}: expected ${expected}, got ${actual}`);
}

expect("text", ["paste", "copy", "edit"]);
expect("link", ["paste", "copy", "edit", "open-url"]);
expect("image", ["paste", "copy", "image-as-file", "annotate"]);
expect("files", ["paste", "copy", "open-file", "reveal-file"]);
expect("html", ["paste", "copy", "edit"]);
expect("json", ["paste", "copy", "edit"]);
expect("color", ["paste", "copy", "edit"]);
expect("binary", ["copy"]);
if (context.actionLabels["image-as-file"] !== "Paste as file")
    throw new Error("image-as-file must be presented as the alternative image paste action");

for (const kind of ["text", "link", "image", "files", "binary"]) {
    const descriptors = context.actionDescriptorsForKind(kind);
    if (descriptors.some(action => !action.id || !action.label || !["default", "secondary"].includes(action.role)))
        throw new Error(`${kind}: invalid action descriptor`);
    if (descriptors.map(action => action.id).join(",") !== context.actionsForKind(kind).join(","))
        throw new Error(`${kind}: descriptor IDs differ from action matrix`);
}
console.log("clipboard action matrix checks passed");
