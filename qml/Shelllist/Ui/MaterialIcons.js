.pragma library

// Existing semantic glyphs stay valid; unmapped specialist icons use the
// packaged Nerd Font rather than being replaced with misleading symbols.
const symbols = {
    "󰅂": "chevron_right", "⋯": "more_horiz", "󰈀": "lan", "󰤮": "wifi_off",
    "󰕾": "volume_up", "󰖀": "volume_down", "󰍬": "mic", "󰎆": "music_note",
    "󰕍": "restore", "replay_30": "replay_30", "forward_30": "forward_30",
    "󰀻": "apps", "󰖩": "wifi", "": "wifi", "󰂯": "bluetooth", "": "bluetooth",
    "󰅇": "content_paste", "󰍹": "monitor", "󰃭": "calendar_month", "": "notifications",
    "󰅐": "schedule", "󰒓": "settings", "󰋜": "home", "󰆴": "delete", "󰅖": "close",
    "filter_1": "filter_1",
    "󰆍": "terminal", "󰖟": "language", "󰅩": "code",
    "󰎈": "music_note", "󰈙": "description",
    "settings": "settings", "mouse": "mouse", "keyboard": "keyboard", "apps": "apps",
    "arrow_selector_tool": "arrow_selector_tool", "chevron_right": "chevron_right",
    "info": "info", "help_outline": "help_outline", "error": "error",
    "expand_less": "expand_less", "expand_more": "expand_more",
    "󰑓": "refresh", "󰁍": "arrow_back", "󰅀": "expand_more", "󰏫": "edit",
    "󰒊": "send", "󰌾": "lock", "󰈈": "visibility", "󰈉": "visibility_off",
    "": "play_arrow", "": "pause", "": "skip_previous", "": "skip_next",
    "󰄪": "monitoring", "󰂚": "notifications_none", "󰂛": "notifications_off"
};
// Explicit semantic names used by shared command/header controls. Never treat
// arbitrary application-provided text as a Material ligature.
const commandSymbols = [
    "search", "history", "calendar_month", "checklist", "notifications_none", "wifi_off",
    "wifi", "today", "refresh", "arrow_back", "arrow_forward", "arrow_upward",
    "arrow_downward", "chevron_left", "more_horiz", "play_arrow", "pause",
    "restore", "undo", "check", "close", "delete", "cancel", "help", "monitor",
    "speaker", "mic", "autorenew", "battery_charging_full", "battery_saver",
    "clear_all", "qr_code", "qr_code_scanner", "content_copy", "content_paste",
    "open_in_new", "unfold_more", "reply", "snooze", "schedule", "notifications", "notifications_off",
    "contrast", "desktop_windows", "center_focus_strong", "warning", "share", "bluetooth", "volume_up",
    "music_note", "settings_input_component", "memory", "storage", "bolt", "power", "priority_high", "battery_full", "cloud",
    "headphones", "auto_stories", "videocam", "equalizer", "stop", "skip_next", "skip_previous",
    "lock", "block", "text_fields", "lan", "route", "dns", "language", "key", "category",
    "aspect_ratio", "rotate_90_degrees_cw", "format_size",
    "memory_alt", "developer_board", "hard_drive", "inventory_2", "folder",
    "list", "article", "find_in_page", "eco", "tune", "shield", "link", "link_off",
    "bedtime", "coffee", "laptop", "battery_alert", "battery_0_bar", "battery_6_bar", "wb_sunny"
];
function name(glyph) {
    return Object.prototype.hasOwnProperty.call(symbols, glyph) ? symbols[glyph]
        : commandSymbols.indexOf(glyph) >= 0 ? glyph : "";
}
