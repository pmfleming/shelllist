pragma Singleton
import QtQml
import Quickshell

// Shared by rows, headers and toasts without constructing hidden image items.
// Missing Quickshell URLs can load as checkerboards, so check theme names first.
QtObject {
    function fallback(notification: var): string {
        const name = String(notification?.app_name || "").trim();
        return name ? Array.from(name)[0].toUpperCase() : "notifications";
    }
    function resolve(notification: var): string {
        const n = notification || ({});
        const hints = n.hints || ({});
        // Content imagery (image-path/image-data) is never app identity.
        // The daemon captures Icon= from the desktop entry for new records.
        const desktop = String(hints.desktop_entry || hints["desktop-entry"] || "").replace(/\.desktop$/, "");
        const known = {Signal: "org.signal.Signal", Thunderbird: "thunderbird", satty: "com.gabm.satty", Zen: "zen-browser"};
        const internal = ["bar-daemon", "clip-daemon", "Shelllist"].includes(n.app_name);
        const candidates = [n.identity_icon, desktop, internal ? "" : n.app_icon, Object.prototype.hasOwnProperty.call(known, n.app_name) ? known[n.app_name] : "",
            n.app_name, String(n.app_name || "").toLowerCase()];
        for (const value of candidates) {
            const candidate = String(value || "").trim();
            if (candidate.startsWith("/")) return "file://" + candidate;
            if (candidate.startsWith("file://")) return candidate;
            if (!candidate) continue;
            // Adwaita ships many status/action icons only in symbolic form.
            for (const name of [candidate, candidate.endsWith("-symbolic") ? "" : candidate + "-symbolic"])
                if (name && Quickshell.hasThemeIcon(name)) return Quickshell.iconPath(name);
        }
        return "";
    }
}
