.pragma library

function action(id, label, icon, enabled) {
    return {id: id, label: label, icon: icon, enabled: !!enabled, closePolicy: "keep-open",
        presentation: {group: "toolbar"}};
}
function entry(id, title, subtitle, icon, actions, direction) {
    return {id: id, title: title, subtitle: subtitle, icon: icon, payload: id,
        searchText: title + " " + subtitle, primaryActionId: "inspect",
        metadata: {direction: direction || ""},
        actions: [{id: "inspect", label: "Inspect", closePolicy: "keep-open",
            presentation: {group: "primary"}}].concat(actions || [])};
}
function audio(state, busy) {
    const result = [];
    if (state.available)
        result.push(entry("output:" + state.sink_name, state.sink_description || "Default output",
            state.muted ? "Muted" : String(state.volume_percent) + "%", "󰕾", [
                action("quieter", "Decrease volume 5%", "󰖀", !busy),
                action("louder", "Increase volume 5%", "󰕾", !busy),
                action("mixer", "Open full audio mixer", "󰒓", true)
            ], "output"));
    if (state.input_available)
        result.push(entry("input:" + state.source_name, state.source_description || "Default input",
            state.input_muted ? "Microphone muted" : "Microphone enabled", "󰍬", [
                action("mixer", "Open full audio mixer", "󰒓", true)
            ], "input"));
    return result;
}
function media(players, busy) {
    return (players || []).map(function (player) {
        const control = !!player.can_control && !busy;
        return entry(player.id, player.title || player.identity, [player.identity, player.artist, player.playback_status].filter(Boolean).join(" · "), "󰎆", [
            action("previous", "Previous track", "", control && player.can_previous),
            action("play-pause", "Play/pause", "", control && (player.playback_status === "Playing" ? player.can_pause : player.can_play)),
            action("next", "Next track", "", control && player.can_next),
            action("rewind", "Rewind 30 seconds", "󰕍", control && player.can_seek),
            action("forward", "Fast-forward 30 seconds", "󰕏", control && player.can_seek)
        ]);
    });
}
function tray(items) {
    const groups = Object.create(null);
    Array.from(items).forEach(function (item) {
        if (item.id) {
            const key = String(item.id);
            if (!groups[key]) groups[key] = [];
            groups[key].push(item);
        }
    });
    return Object.keys(groups).map(function (id) {
        const item = groups[id][0], unique = groups[id].length === 1;
        return entry(id, item.title || id, unique ? (item.tooltipDescription || item.tooltipTitle || id) : "Ambiguous tray identity; actions unavailable", "󰀻", [
            action("activate", "Activate application", "󰀻", unique && !item.onlyMenu),
            action("menu", "Open application menu", "󰒓", unique && item.hasMenu),
            action("secondary", "Secondary activation", "󰋜", unique && !item.onlyMenu),
            action("scroll-up", "Scroll application up", "󰁝", unique),
            action("scroll-down", "Scroll application down", "󰁅", unique)
        ]);
    });
}
