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
console.log("clipboard action matrix checks passed");
