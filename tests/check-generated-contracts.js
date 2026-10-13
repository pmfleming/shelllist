#!/usr/bin/env node
// Execute the shared generated JS itself, never regex-extracted QML functions.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.argv[2] || path.resolve(__dirname, '..');
function load(file) {
    const context = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\.pragma library\s*/m, ''), context);
    return context;
}
const app = load('launcher/AppProtocol.generated.js');
const bar = load('bar/BarProtocol.generated.js');
const fixture = name => JSON.parse(fs.readFileSync(path.join(root, 'tests/qml/fixtures', name), 'utf8'));
const replies = fixture('app-replies.json');
assert.equal(Object.keys(app.contracts).length, 8);
for (const [method, contract] of Object.entries(app.contracts)) {
    assert.equal(app.responseError(method, replies[method]), '', method);
    const moved = structuredClone(replies[method]);
    moved[contract.response_key] = moved.data[contract.response_key];
    delete moved.data[contract.response_key];
    assert.notEqual(app.responseError(method, moved), '', method);
}
const controls = fixture('bar-controls.json');
assert.equal(Object.keys(bar.contracts).length, 3);
for (const method of Object.keys(bar.contracts)) {
    const example = controls[method];
    assert.equal(bar.requestError(method, example.params), '', method);
    assert.notEqual(bar.requestError(method, example.invalid_params), '', method);
    for (const outcome of ['success', 'limited']) assert.equal(bar.responseError(method, example[outcome]), '', method);
    const changed = structuredClone(example.success);
    delete changed.data.audio.volume_percent;
    assert.notEqual(bar.responseError(method, changed), '', method);
}
const validate = app.schemaError;
for (const [schema, valid, invalid] of [
    [{type:'integer'}, 12, 9007199254740992],
    [{type:['string','null']}, null, false],
    [{type:'object',required:['a'],properties:{a:{type:'boolean'}},additionalProperties:false}, {a:true}, {a:true,b:1}],
    [{type:'array',items:{type:'integer'},minItems:1,maxItems:2}, [1], [1,'2']],
    [{anyOf:[{type:'string'},{type:'boolean'}]}, 'x', 1],
    [{oneOf:[{type:'number'},{type:'integer'}]}, 1.5, 1],
    [{allOf:[{type:'number'},{minimum:1}]}, 2, 0],
    [{type:'string',pattern:'^[a-z]+$',minLength:2,maxLength:3}, 'ab', 'A'],
    [{$defs:{thing:{type:'string'}},$ref:'#/$defs/thing'}, 'x', 1],
]) {
    assert.equal(validate(schema, valid), '');
    assert.notEqual(validate(schema, invalid), '');
}
console.log('generated contracts: production replies, invalid requests and payload mutations passed');
