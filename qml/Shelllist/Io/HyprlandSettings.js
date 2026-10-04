.pragma library

function layerStyle(namespace, noMotion, blur) {
    const pattern = "^" + namespace.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
    return ["hyprctl", "eval", "hl.layer_rule({ name = " + JSON.stringify("shelllist-style-" + namespace)
        + ", match = { namespace = " + JSON.stringify(pattern) + " }, blur = " + String(blur)
        + ", ignore_alpha = 0.01, no_anim = " + String(noMotion) + " })"];
}
