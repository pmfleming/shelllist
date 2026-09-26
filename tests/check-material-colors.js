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
// Reference vectors from upstream 0.4.0 SchemeTonalSpot, spec 2021, contrast 0.
for (const [seed, dark, primary, surface] of [
    ['#6750a4', false, '#65558f', '#fdf7ff'], ['#6750a4', true, '#cfbdfe', '#141218'],
    ['#009688', false, '#006a60', '#f4fbf8'], ['#009688', true, '#82d5c8', '#0e1513'],
    ['#ff0000', false, '#904b40', '#fff8f6'], ['#ff0000', true, '#ffb4a8', '#1a1110']
]) {
    const colors = create(seed, dark);
    assert.equal(colors.primary, primary);
    assert.equal(colors.surface, surface);
}
const seeds = ['#000000', '#ffffff', '#808080', '#ff0000', '#00ff00', '#0000ff', '#ffff00', '#00ffff', '#ff00ff', '#6750a4', '#009688'];
for (let hue = 0; hue < 64; hue++) seeds.push('#' + ((hue * 2654435761) >>> 8).toString(16).padStart(6, '0'));
for (const seed of seeds) for (const dark of [false, true]) {
    const colors = create(seed, dark);
    for (const value of Object.values(colors)) assert.match(value, /^#[0-9a-f]{6}$/);
    for (const role of ['primary', 'secondary', 'tertiary', 'error', 'success', 'warning', 'primaryContainer', 'secondaryContainer', 'tertiaryContainer', 'errorContainer']) {
        const on = 'on' + role[0].toUpperCase() + role.slice(1);
        assert.ok(contrast(rgb(colors[role]), rgb(colors[on])) >= 4.5, `${seed}/${dark}: ${role}`);
    }
    for (const surface of ['surface', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer', 'surfaceContainerHigh', 'surfaceContainerHighest']) {
        for (const text of ['onSurface', 'onSurfaceVariant'])
            assert.ok(contrast(rgb(colors[surface]), rgb(colors[text])) >= 4.5, `${seed}/${dark}: ${text}/${surface}`);
        assert.ok(contrast(rgb(colors[surface]), rgb(colors.primary)) >= 3, `${seed}/${dark}: focus/${surface}`);
    }
    // Proposed 94% outer shell over the extremal desktop backgrounds. Controls
    // stay opaque; this does not pretend to test compositor blur or text rendering.
    for (const desktop of [0, 1]) {
        const shell = rgb(colors.surface).map(c => c * 0.94 + desktop * 0.06);
        for (const text of ['onSurface', 'onSurfaceVariant']) assert.ok(contrast(shell, rgb(colors[text])) >= 4.5);
        assert.ok(contrast(shell, rgb(colors.primary)) >= 3);
    }
}
console.log(`Material colors: reference vectors and contrast pass for ${seeds.length * 2} seed/mode combinations`);
