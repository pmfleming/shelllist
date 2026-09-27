.pragma library

function motionDisabled(option) {
    return option && (option.int === 0 || option.bool === false);
}
function layerStyle(namespace, noMotion, blur) {
    const pattern = "^" + namespace.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
    return ["hyprctl", "eval", "hl.layer_rule({ name = " + JSON.stringify("shelllist-style-" + namespace)
        + ", match = { namespace = " + JSON.stringify(pattern) + " }, blur = " + String(blur)
        + ", ignore_alpha = 0.01, no_anim = " + String(noMotion) + " })"];
}
