pragma Singleton

import QtQml

QtObject {
    property var environment: ({})
    function env(name: string): string {
        return environment[name] || "";
    }
    function hasThemeIcon(name: string): bool { return false; }
    function iconPath(name: string, fallback: string): string {
        return "";
    }
}
