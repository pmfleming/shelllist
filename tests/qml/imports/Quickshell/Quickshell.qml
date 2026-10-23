pragma Singleton

import QtQml

QtObject {
    property var environment: ({})
    function env(name: string): string {
        if (name === "SHELLLIST_THEME_OFFLINE")
            return "1"; // UI fixtures bind fixed roles; transport has its own tests.
        return environment[name] || "";
    }
    property var themeIcons: ({})
    function hasThemeIcon(name: string): bool { return !!themeIcons[name]; }
    function iconPath(name: string, fallback: string): string {
        return themeIcons[name] || themeIcons[fallback] || "";
    }
}
