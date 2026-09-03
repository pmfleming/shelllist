#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(readFileSync(join(root, "typescript/manifest.json"), "utf8"));
const check = process.argv.includes("--check");
const temporary = mkdtempSync(join(tmpdir(), "shelllist-typescript-"));

try {
    for (let index = 0; index < manifest.length; ++index) {
        const entry = manifest[index];
        const compiled = join(temporary, `${index}.js`);
        const result = spawnSync(process.env.TSC || "tsc", [
            "--target", "ES2020", "--module", "none", "--strict",
            "--skipLibCheck", "--outFile", compiled, join(root, entry.source)
        ], { encoding: "utf8" });
        if (result.status !== 0)
            throw new Error(result.stdout + result.stderr);
        const output = ".pragma library\n\n" + readFileSync(compiled, "utf8");
        const destination = join(root, entry.output);
        if (check) {
            if (readFileSync(destination, "utf8") !== output)
                throw new Error(`${entry.output} is not generated from ${entry.source}`);
        } else {
            writeFileSync(destination, output);
        }
    }
} finally {
    rmSync(temporary, { recursive: true, force: true });
}
