pragma Singleton
import QtQml

// The daemon classifies devices; these are font assets, not BlueZ rules.
QtObject {
    readonly property var glyphs: ({
        bluetooth: "󰂯", blocked: "󰂲", earbuds: "󱡏", headphones: "󰋋",
        bluetoothHeadphones: "󰥰", headset: "󰋎", chargingCase: "󰋌",
        speaker: "󰓃", keyboard: "󰌌", mouse: "󰍽", controller: "󰊴",
        phone: "󰄜", computer: "󰌢", watch: "󰖉", battery: "󰁹"
    })
    readonly property var batteryIcons: ({left: "earbuds", right: "earbuds", "case": "chargingCase"})
    function forDevice(device: var): string {
        const key = device?.icon_id;
        return Object.prototype.hasOwnProperty.call(glyphs, key) ? glyphs[key] : glyphs.bluetooth;
    }
    function forListDevice(device: var): string {
        return device?.blocked ? glyphs.blocked : forDevice(device);
    }
    function forBattery(report: var): string {
        const key = report?.component;
        return Object.prototype.hasOwnProperty.call(batteryIcons, key) ? glyphs[batteryIcons[key]] : glyphs.battery;
    }
}
