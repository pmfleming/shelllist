#!/usr/bin/env node

const assert = require("assert");
const path = require("path");
const Navigation = require(path.resolve(process.argv[2]));

const none = 0;
const shift = 1;
const control = 2;

assert.strictEqual(Navigation.listDirection("j", none, none, shift), 1);
assert.strictEqual(Navigation.listDirection("J", shift, none, shift), 1);
assert.strictEqual(Navigation.listDirection("k", none, none, shift), -1);
assert.strictEqual(Navigation.listDirection("K", shift, none, shift), -1);
assert.strictEqual(Navigation.listDirection("j", control, none, shift), 0);
assert.strictEqual(Navigation.listDirection("x", none, none, shift), 0);
assert.strictEqual(Navigation.listDirection("", none, none, shift), 0);

console.log("Navigation keys: 7 checks passed");
