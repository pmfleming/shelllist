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
    function candidateSource(value: var): string {
        const candidate = String(value || "").trim();
        if (!candidate) return "";
        if (candidate.startsWith("/")) return "file://" + candidate;
        if (candidate.startsWith("file://")) return candidate;
        if (Quickshell.hasThemeIcon(candidate)) return Quickshell.iconPath(candidate);
        // Adwaita ships many status/action icons only in symbolic form.
        const symbolic = candidate + "-symbolic";
        return !candidate.endsWith("-symbolic") && Quickshell.hasThemeIcon(symbolic) ? Quickshell.iconPath(symbolic) : "";
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
            const source = candidateSource(value);
            if (source) return source;
        }
        return "";
    }
}
