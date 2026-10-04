#!/usr/bin/env node
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8').replace(/^\.pragma library\s*/m, ''), context);
const rgb = hex => [1, 3, 5].map(index => parseInt(hex.slice(index, index + 2), 16) / 255);
const luminance = channels => channels.map(c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4)
    .reduce((value, c, i) => value + c * [0.2126, 0.7152, 0.0722][i], 0);
const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + 0.05) / (Math.min(luminance(a), luminance(b)) + 0.05);
const create = (seed, dark) => context.MaterialColors.createScheme(...rgb(seed), dark);
// Native MaterialPalette tests check foreground binding types. Contrast,
// rather than fixed reference colors or a proposed shell opacity, is the gate.
const seeds = ['#000000', '#ffffff', '#808080', '#ff0000', '#00ff00', '#0000ff', '#ffff00', '#00ffff', '#ff00ff', '#6750a4', '#009688'];
for (let hue = 0; hue < 64; hue++) seeds.push('#' + ((hue * 2654435761) >>> 8).toString(16).padStart(6, '0'));
for (const seed of seeds) for (const dark of [false, true]) {
    const colors = create(seed, dark);
    for (const role of ['primary', 'secondary', 'tertiary', 'error', 'success', 'warning', 'primaryContainer', 'secondaryContainer', 'tertiaryContainer', 'errorContainer']) {
        const on = 'on' + role[0].toUpperCase() + role.slice(1);
        assert.ok(contrast(rgb(colors[role]), rgb(colors[on])) >= 4.5, `${seed}/${dark}: ${role}`);
    }
    for (const surface of ['surface', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer', 'surfaceContainerHigh', 'surfaceContainerHighest']) {
        for (const text of ['onSurface', 'onSurfaceVariant'])
            assert.ok(contrast(rgb(colors[surface]), rgb(colors[text])) >= 4.5, `${seed}/${dark}: ${text}/${surface}`);
        assert.ok(contrast(rgb(colors[surface]), rgb(colors.primary)) >= 3, `${seed}/${dark}: focus/${surface}`);
    }
}
console.log(`Material colors: contrast passes for ${seeds.length * 2} seed/mode combinations`);
