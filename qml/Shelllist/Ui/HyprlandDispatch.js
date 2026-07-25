.pragma library

function luaString(value) { return JSON.stringify(String(value)); }
function request(usingLua, legacyRequest, luaDispatcher) {
    return usingLua ? luaDispatcher : legacyRequest;
}

function windowProperty(usingLua, selector, legacyName, legacyValue, luaName, luaValue) {
    return request(usingLua,
        "setprop " + selector + " " + legacyName + " " + legacyValue,
        "hl.dsp.window.set_prop({ prop = " + luaString(luaName)
            + ", value = " + luaString(luaValue) + ", window = " + luaString(selector) + " })");
}

function focusWindow(usingLua, selector) {
    return request(usingLua, "focuswindow " + selector,
        "hl.dsp.focus({ window = " + luaString(selector) + " })");
}

function floatWindow(usingLua, selector) {
    return request(usingLua, "setfloating " + selector,
        "hl.dsp.window.float({ action = \"set\", window = " + luaString(selector) + " })");
}

function moveWindow(usingLua, selector, x, y) {
    return request(usingLua, "movewindowpixel exact " + x + " " + y + "," + selector,
        "hl.dsp.window.move({ x = " + x + ", y = " + y + ", window = " + luaString(selector) + " })");
}
