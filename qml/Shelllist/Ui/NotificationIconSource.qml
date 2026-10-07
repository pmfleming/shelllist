pragma Singleton
import QtQml
import Quickshell

// Shared by rows, headers and toasts without constructing hidden image items.
// Missing Quickshell URLs can load as checkerboards, so check theme names first.
QtObject {
    function resolve(notification: var): string {
        const n = notification || ({});
        const hints = n.hints || ({});
        const candidates = [hints.image_path, n.app_icon, hints.desktop_entry,
            n.app_name, String(n.app_name || "").toLowerCase()];
        for (const value of candidates) {
            const candidate = String(value || "").trim();
            if (candidate.startsWith("/")) return "file://" + candidate;
            if (candidate.startsWith("file://")) return candidate;
            if (candidate && Quickshell.hasThemeIcon(candidate)) return Quickshell.iconPath(candidate);
        }
        return "";
    }
}
