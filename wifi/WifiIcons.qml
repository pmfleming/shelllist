pragma Singleton
import QtQml

QtObject {
    readonly property var icons: ({
        "captive-portal": "󱚵",
        "open": "󰌿",
        "enhanced-open": "󱦚",
        "legacy": "󰣮",
        "personal": "󰌾",
        "enterprise": "󰢏",
        "unknown": "󰣯"
    })
    function forNetwork(network: var, captivePortal: bool): string {
        const key = captivePortal ? "captive-portal" : network?.security_class;
        return Object.prototype.hasOwnProperty.call(icons, key) ? icons[key] : icons.unknown;
    }
}
