#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const root = process.argv[2];
if (!root)
    throw new Error("usage: check-packaged-imports.js <installed-share/shelllist>");

const failures = [];

function visit(entry) {
    const stat = fs.statSync(entry);
    if (stat.isDirectory()) {
        for (const child of fs.readdirSync(entry))
            visit(path.join(entry, child));
        return;
    }
    if (!entry.endsWith(".js") && !entry.endsWith(".qml"))
        return;
    const source = fs.readFileSync(entry, "utf8");
    const expression = entry.endsWith(".js")
        ? /^\s*\.import\s+"([^"]+)"/gm
        : /^\s*import\s+"([^"]+)"/gm;
    for (const match of source.matchAll(expression)) {
        const target = path.resolve(path.dirname(entry), match[1]);
        if (!fs.existsSync(target))
            failures.push(`${path.relative(root, entry)} -> ${match[1]}`);
    }
}

visit(path.join(root, "shell"));
visit(path.join(root, "qml", "Shelllist"));

if (failures.length > 0)
    throw new Error("installed relative imports do not resolve:\n" + failures.join("\n"));

console.log("packaged relative imports resolve");
