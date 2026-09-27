.pragma library

// Existing semantic glyphs stay valid; unmapped specialist icons use the
// packaged Nerd Font rather than being replaced with misleading symbols.
const symbols = {
    "󰀻": "apps", "󰖩": "wifi", "": "wifi", "󰂯": "bluetooth", "": "bluetooth",
    "󰅇": "content_paste", "󰍹": "monitor", "󰃭": "calendar_month", "": "notifications",
    "󰅐": "schedule", "󰒓": "settings", "󰋜": "home", "󰆴": "delete", "󰅖": "close",
    "󰑓": "refresh", "󰁍": "arrow_back", "󰅀": "expand_more", "󰏫": "edit",
    "󰒊": "send", "󰌾": "lock", "󰈈": "visibility", "󰈉": "visibility_off",
    "": "play_arrow", "": "pause", "": "skip_previous", "": "skip_next",
    "󰄪": "monitoring", "󰂚": "notifications_none", "󰂛": "notifications_off"
};
function name(glyph) { return symbols[glyph] || ""; }
