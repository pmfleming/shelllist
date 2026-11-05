import QtQuick
import QtTest
import "../../qml/Shelllist/Ui/HyprlandDispatch.js" as Dispatch

TestCase {
    name: "HyprlandLuaDispatch"
    function test_lua_only_builders_quote_selectors() {
        const selector = "title:quote\"; not_code()";
        compare(Dispatch.focusWindow(selector), "hl.dsp.focus({ window = " + JSON.stringify(selector) + " })");
        verify(Dispatch.floatWindow(selector).startsWith("hl.dsp.window.float("));
        verify(Dispatch.moveWindow(selector, -10, 20).includes("x = -10, y = 20"));
        compare(Dispatch.windowProperty(selector, "no_anim", "1"), "hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"1\", window = " + JSON.stringify(selector) + " })");
    }
}
