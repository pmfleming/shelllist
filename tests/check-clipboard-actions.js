#!/usr/bin/env node

const fs = require("fs");
const vm = require("vm");

const apiPath = process.argv[2];
const helperPath = process.argv[3];
if (!apiPath || !helperPath)
    throw new Error("usage: check-clipboard-actions.js <ClipApi.js> <ApiEnvelope.js>");
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/, ""), context);
context.ApiEnvelope = {
    compatibilityError: context.compatibilityError,
    responseError: context.responseError
};
const source = fs.readFileSync(apiPath, "utf8")
    .replace(/^\.pragma library\s*/, "").replace(/^\.import.*$/gm, "");
vm.runInContext(source, context);
if (context.responseError({ protocol: "clip-api", version: 1, ok: true }, "") !== "")
    throw new Error("valid clip-api envelope was rejected");
if (!context.responseError({ protocol: "wrong", version: 1, ok: true }, "").includes("incompatible"))
    throw new Error("incompatible clip-api envelope was accepted");

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

for (const kind of ["text", "link", "image", "files", "binary"]) {
    const descriptors = context.actionDescriptorsForKind(kind);
    if (descriptors.some(action => !action.id || !action.label || !["default", "secondary"].includes(action.role)))
        throw new Error(`${kind}: invalid action descriptor`);
    if (descriptors.map(action => action.id).join(",") !== context.actionsForKind(kind).join(","))
        throw new Error(`${kind}: descriptor IDs differ from action matrix`);
}
console.log("clipboard action matrix checks passed");
