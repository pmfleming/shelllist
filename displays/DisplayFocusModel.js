.pragma library

function choice(key, title, help, labels) {
    return {
        key: key,
        title: title,
        help: help,
        choices: labels.map((label, index) => ({
                    value: String(index),
                    label: label
                }))
    };
}
function toggle(key, title, help) {
    const item = choice(key, title, help, ["Off", "On"]);
    item.boolean = true;
    item.choices = [
        {
            value: "false",
            label: "Off"
        },
        {
            value: "true",
            label: "On"
        }
    ];
    return item;
}
function number(key, title, help, maximum, whole, unit) {
    return {
        key: key,
        title: title,
        help: help,
        maximum: maximum,
        whole: whole,
        unit: unit || "",
        choices: []
    };
}
function groups() {
    return [
        {
            id: "pointer", title: "Pointer", icon: "mouse",
            summary: "Thresholds and focus exceptions",
            settings: [choice("input:follow_mouse", "Window focus", "Window focus and active-monitor selection are related but separate. Detached sends pointer input to hovered windows; Separate also avoids refocusing on click.", ["Click to focus", "Focus follows pointer", "Detached pointer focus", "Separate pointer and keyboard focus"]), toggle("misc:mouse_move_focuses_monitor", "Activate monitor on pointer entry", "Crossing a screen boundary selects that monitor. Turning this off alone does not stop a hovered window from gaining keyboard focus; also choose Click to focus for keyboard-led use."), toggle("input:mouse_refocus", "Refocus on pointer movement", "With focus following the pointer, mouse movement can reclaim focus after a keyboard switch. Off requires crossing a window boundary."), number("input:follow_mouse_threshold", "Refocus distance", "Minimum pointer travel in logical pixels for focus-following behaviour (0–1000).", 1000, false, "px"), number("input:follow_mouse_shrink", "Window-edge dead zone", "Shrinks inactive window focus hitboxes in logical pixels (0–300). Applies when focus follows the pointer.", 300, true, "px"), choice("input:float_switch_override_focus", "Floating-window focus exceptions", "Allows pointer-based refocusing between tiled and floating windows even without ordinary focus following.", ["No exceptions", "Between tiled and floating", "Also between floating windows"]), toggle("misc:always_follow_on_dnd", "Follow the pointer while dragging data", "Temporarily use pointer-following focus during drag and drop."), toggle("misc:layers_hog_keyboard_focus", "Keep keyboard focus in panels and launchers", "Keyboard-interactive layer surfaces retain focus when the pointer moves."), toggle("input:special_fallthrough", "Focus through floating special workspaces", "A special workspace containing only floating windows does not block focusing regular-workspace windows.")]
        },
        {
            id: "keyboard", title: "Keyboard", icon: "keyboard",
            summary: "Directional focus and workspace history",
            settings: [toggle("binds:window_direction_monitor_fallback", "Cross monitors with directional keys", "At a monitor edge, directional focus or window-move commands may use the adjacent monitor. This does not restrict explicit monitor or last-window shortcuts."), choice("binds:focus_preferred_method", "Choose directional focus targets by", "When several windows lie in the requested direction, prefer focus history or the longest shared edge.", ["Focus history", "Longest shared edge"]), toggle("binds:movefocus_cycles_fullscreen", "Cycle fullscreen windows with directional focus", "Directional focus cycles while on a fullscreen window."), toggle("binds:movefocus_cycles_groupfirst", "Cycle grouped windows first", "Directional focus visits windows in the current group before leaving it."), toggle("binds:workspace_back_and_forth", "Workspace back and forth", "A repeated workspace selection switches back instead of staying put."), toggle("binds:allow_workspace_cycles", "Retain previous-workspace history", "Keep workspace history available for cycling."), toggle("binds:hide_special_on_workspace_change", "Hide special workspace on switch", "Changing the active workspace hides the special workspace on that monitor.")]
        },
        {
            id: "applications", title: "Applications", icon: "apps",
            summary: "Activation, closing and launch behaviour",
            settings: [toggle("misc:focus_on_activate", "Allow activation requests", "An application requesting activation can take keyboard focus, potentially activating another monitor. Per-window rules may override this."), choice("input:focus_on_close", "After closing a window, focus", "Select the next window using layout order, the pointer or most-recently-used history.", ["Next layout candidate", "Window under pointer", "Most recently used"]), choice("misc:on_focus_under_fullscreen", "Focus behind fullscreen", "Controls a tiled window requesting focus behind a fullscreen or maximized window.", ["Ignore the request", "Transfer fullscreen", "Exit fullscreen"]), choice("misc:initial_workspace_tracking", "Track launching workspace", "Track where applications were launched rather than only where focus happens to be when their windows appear.", ["Do not track", "Initial window", "Persistent tracking"])]
        },
        {
            id: "cursor", title: "Cursor", icon: "arrow_selector_tool",
            summary: "Automatic movement and remembered positions",
            settings: [toggle("cursor:no_warps", "Prevent automatic cursor jumps", "Suppress cursor warping in many focus-switching operations. Explicit or forced warps can still move it."), toggle("cursor:persistent_warps", "Remember cursor position", "When refocusing a window, restore the last relative cursor position instead of its centre."), choice("cursor:warp_on_change_workspace", "Cursor on workspace switch", "Forced movement overrides the no-warps preference.", ["Do not move", "Move when warps are allowed", "Force movement"]), choice("cursor:warp_on_toggle_special", "Cursor on special workspace toggle", "Move to the last focused window; forced movement overrides the no-warps preference.", ["Do not move", "Move when warps are allowed", "Force movement"]), choice("binds:workspace_center_on", "Workspace cursor destination", "Choose the destination for workspace-switching cursor centring.", ["Workspace centre", "Last active window"]), toggle("cursor:warp_back_after_non_mouse_input", "Restore cursor after other input", "Return the cursor to its previous position after non-mouse input moved it.")]
        }
    ];
}
function validNumber(item, text) {
    const value = Number(text);
    return String(text).trim().length > 0 && Number.isFinite(value) && value >= 0 && value <= item.maximum && (!item.whole || Number.isInteger(value));
}
function value(item, selected) {
    return item.boolean ? selected === "true" : Number(selected);
}
