.pragma library

function luaString(value) {
    return JSON.stringify(String(value));
}
function windowProperty(selector, name, value) {
    return "hl.dsp.window.set_prop({ prop = " + luaString(name) + ", value = " + luaString(value) + ", window = " + luaString(selector) + " })";
}
function focusWindow(selector) {
    return "hl.dsp.focus({ window = " + luaString(selector) + " })";
}
function floatWindow(selector) {
    return "hl.dsp.window.float({ action = \"set\", window = " + luaString(selector) + " })";
}
function moveWindow(selector, x, y) {
    return "hl.dsp.window.move({ x = " + x + ", y = " + y + ", window = " + luaString(selector) + " })";
}
