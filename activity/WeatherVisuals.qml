pragma Singleton
import QtQml

QtObject {
    // Asset identity and colours only. Numeric labels and forecast projections
    // arrive in native display/clock_display metadata.
    readonly property var icons: ({
        0: "clear", 1: "partly-cloudy", 2: "partly-cloudy", 3: "overcast",
        45: "fog", 48: "fog",
        51: "drizzle", 52: "drizzle", 53: "drizzle", 54: "drizzle", 55: "drizzle", 56: "drizzle", 57: "drizzle",
        61: "rain", 62: "rain", 63: "rain", 64: "rain", 65: "rain", 66: "rain", 67: "rain",
        71: "snow", 72: "snow", 73: "snow", 74: "snow", 75: "snow", 76: "snow", 77: "snow",
        80: "rain", 81: "rain", 82: "rain", 85: "snow", 86: "snow",
        95: "thunderstorms", 96: "thunderstorms", 97: "thunderstorms", 98: "thunderstorms", 99: "thunderstorms"
    })
    readonly property var periodIcons: ["clear", "partly-cloudy", "overcast", "fog", "thunderstorms"]
    readonly property var heroColors: ({
        night: ["#111c3a", "#18243d"], storm: ["#28203f", "#182237"],
        wet: ["#173451", "#1c2d42"], overcast: ["#263748", "#1c2937"], clear: ["#18466b", "#1b3452"]
    })
    function iconName(code: var, daytime: bool): string {
        const name = typeof code === "number" && Number.isInteger(code) && Object.prototype.hasOwnProperty.call(icons, code) ? icons[code] : "not-available";
        return periodIcons.indexOf(name) < 0 ? name : name + (daytime ? "-day" : "-night");
    }
    function hasLocationClock(city: var): bool {
        return !!city && city.clock_unavailable !== true && typeof city.clock_display?.time === "string" && city.clock_display.time.length > 0;
    }
    function locationSubtitle(city: var): string {
        return city?.subtitle || (hasLocationClock(city) ? city.timezone : qsTr("Timezone unavailable"));
    }
}
