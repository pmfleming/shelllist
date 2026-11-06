.pragma library

var daemons = ["bar-daemon", "bar-notification-daemon", "bar-power-daemon", "bar-compositor-daemon", "bar-activity-daemon"];
var streamsByDaemon = {
    "bar-notification-daemon": ["notifications.changed", "notifications.active.changed"],
    "bar-power-daemon": ["battery.changed", "power-profile.changed", "power-sleep.changed", "sleep-policy.changed"],
    "bar-compositor-daemon": ["workspaces.changed", "workarea.changed", "compositor.changed", "display-policy.changed"],
    "bar-activity-daemon": ["activity.changed", "timezone.changed"]
};
function daemonForStream(stream) {
    for (var daemon in streamsByDaemon) {
        if (streamsByDaemon[daemon].includes(stream)) return daemon;
    }
    return "bar-daemon";
}
function daemonForProjection(projection) {
    var stream = {power_profile: "power-profile.changed", power_sleep: "power-sleep.changed",
        sleep_policy: "sleep-policy.changed", display_policy: "display-policy.changed",
        osd_hardware: "osd-hardware.changed", notification_active: "notifications.active.changed"}[projection];
    return daemonForStream(stream || projection + ".changed");
}
function selectStreams(streams, daemon) {
    return Array.from(streams).filter(function(stream) { return daemonForStream(stream) === daemon; });
}
