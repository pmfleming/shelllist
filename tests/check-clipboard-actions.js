#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const apiPath = process.argv[2];
if (!apiPath)
    throw new Error("usage: check-clipboard-actions.js <ClipApi.js>");
const source = fs.readFileSync(apiPath, "utf8");
const importMatch = source.match(/^\.import\s+"([^"]+)"\s+as\s+Protocol$/m);
const context = {};
if (importMatch) {
    const generated = fs.readFileSync(require("path").resolve(require("path").dirname(apiPath), importMatch[1]), "utf8")
        .replace(/^\.pragma library\s*/, "");
    const protocol = {};
    vm.createContext(protocol);
    vm.runInContext(generated, protocol);
    context.Protocol = protocol;
}
vm.createContext(context);
vm.runInContext(source.replace(/^\.pragma library\s*/, "").replace(/^\.import.*$/m, ""), context);

function expect(kind, expected) {
    const actual = context.actionsForKind(kind);
    if (JSON.stringify(actual) !== JSON.stringify(expected))
        throw new Error(`${kind}: expected ${expected}, got ${actual}`);
}

expect("text", ["paste"]);
expect("link", ["paste", "copy", "edit", "open-url"]);
expect("image", ["paste", "image-as-file", "annotate"]);
expect("files", ["paste", "copy", "open-file", "reveal-file"]);
expect("html", ["paste", "copy", "edit"]);
expect("json", ["paste", "copy", "edit"]);
expect("color", ["paste", "copy", "edit"]);
expect("binary", ["copy"]);
if (context.actionLabels["image-as-file"] !== "Paste as file")
    throw new Error("image-as-file must be presented as the alternative image paste action");
if (context.actionLabels.annotate !== "Edit")
    throw new Error("image annotation must be presented as editing");

for (const kind of ["text", "link", "image", "files", "binary"]) {
    const descriptors = context.actionDescriptorsForKind(kind);
    if (descriptors.some(action => !action.id || !action.label || !["default", "secondary"].includes(action.role)))
        throw new Error(`${kind}: invalid action descriptor`);
    if (descriptors.map(action => action.id).join(",") !== context.actionsForKind(kind).join(","))
        throw new Error(`${kind}: descriptor IDs differ from action matrix`);
    const primary = descriptors.filter(action => action.presentation.group === "primary");
    if (primary.length !== 1 || primary[0].role !== "default")
        throw new Error(`${kind}: expected exactly one default primary action`);
    if (descriptors.filter(action => action.presentation.group === "toolbar").some(action => action.role !== "secondary"))
        throw new Error(`${kind}: toolbar actions must be secondary`);
}
console.log("clipboard action matrix checks passed");
