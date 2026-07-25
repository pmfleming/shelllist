import QtQuick
import QtTest
import "../../qml/Shelllist/Ui/HyprlandDispatch.js" as Dispatch

TestCase {
    name: "HyprlandDispatch"

    readonly property string selector: "title:Shelllist Wi-Fi"

    function test_buildsLuaPropertyDispatcher() {
        compare(Dispatch.windowProperty(true, selector, "noanim", "1", "no_anim", "1"),
            "hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"1\", window = \"title:Shelllist Wi-Fi\" })");
    }

    function test_retainsLegacyPropertyDispatcher() {
        compare(Dispatch.windowProperty(false, selector, "noborder", "1", "decorate", "0"),
            "setprop title:Shelllist Wi-Fi noborder 1");
    }

    function test_buildsTargetedLuaPlacement() {
        compare(Dispatch.focusWindow(true, selector),
            "hl.dsp.focus({ window = \"title:Shelllist Wi-Fi\" })");
        compare(Dispatch.floatWindow(true, selector),
            "hl.dsp.window.float({ action = \"set\", window = \"title:Shelllist Wi-Fi\" })");
        compare(Dispatch.moveWindow(true, selector, 120, 80),
            "hl.dsp.window.move({ x = 120, y = 80, window = \"title:Shelllist Wi-Fi\" })");
    }
}
