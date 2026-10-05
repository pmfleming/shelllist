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
    "settings": "settings", "mouse": "mouse", "keyboard": "keyboard", "apps": "apps",
    "arrow_selector_tool": "arrow_selector_tool", "chevron_right": "chevron_right",
    "info": "info", "help_outline": "help_outline", "error": "error",
    "expand_less": "expand_less", "expand_more": "expand_more",
    "󰑓": "refresh", "󰁍": "arrow_back", "󰅀": "expand_more", "󰏫": "edit",
    "󰒊": "send", "󰌾": "lock", "󰈈": "visibility", "󰈉": "visibility_off",
    "": "play_arrow", "": "pause", "": "skip_previous", "": "skip_next",
    "󰄪": "monitoring", "󰂚": "notifications_none", "󰂛": "notifications_off"
};
function name(glyph) { return Object.prototype.hasOwnProperty.call(symbols, glyph) ? symbols[glyph] : ""; }
