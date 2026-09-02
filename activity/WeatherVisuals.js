.pragma library

const ICON_BY_CODE = {
    0: "clear", 1: "partly-cloudy", 2: "partly-cloudy", 3: "overcast",
    45: "fog", 48: "fog",
    51: "drizzle", 52: "drizzle", 53: "drizzle", 54: "drizzle", 55: "drizzle",
    56: "drizzle", 57: "drizzle",
    61: "rain", 62: "rain", 63: "rain", 64: "rain", 65: "rain", 66: "rain", 67: "rain",
    71: "snow", 72: "snow", 73: "snow", 74: "snow", 75: "snow", 76: "snow", 77: "snow",
    80: "rain", 81: "rain", 82: "rain", 85: "snow", 86: "snow",
    95: "thunderstorms", 96: "thunderstorms", 97: "thunderstorms",
    98: "thunderstorms", 99: "thunderstorms"
};
const PERIOD_ICONS = ["clear", "partly-cloudy", "overcast", "fog", "thunderstorms"];

function iconName(code, isDay) {
    const name = ICON_BY_CODE[Number(code)] || "not-available";
    if (PERIOD_ICONS.indexOf(name) < 0)
        return name;
    const daytime = isDay === undefined || isDay === null ? true : !!isDay;
    return name + (daytime ? "-day" : "-night");
}

function shiftedDate(unixMs, utcOffsetSeconds) {
    return new Date(Number(unixMs || 0) + Number(utcOffsetSeconds || 0) * 1000);
}

function twoDigits(value) {
    return String(value).padStart(2, "0");
}

function localTime(unixMs, utcOffsetSeconds) {
    const value = shiftedDate(unixMs, utcOffsetSeconds);
    return twoDigits(value.getUTCHours()) + ":" + twoDigits(value.getUTCMinutes());
}

function localDay(unixMs, utcOffsetSeconds) {
    const names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return names[shiftedDate(unixMs, utcOffsetSeconds).getUTCDay()];
}

function windCompass(degrees) {
    const names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    const normalized = ((Number(degrees || 0) % 360) + 360) % 360;
    return names[Math.round(normalized / 45) % names.length];
}

function heroColors(code, isDay) {
    const value = Number(code);
    if (!isDay)
        return ["#111c3a", "#18243d"];
    if (value >= 95)
        return ["#28203f", "#182237"];
    if ((value >= 51 && value <= 67) || (value >= 80 && value <= 86))
        return ["#173451", "#1c2d42"];
    if (value === 3 || value === 45 || value === 48)
        return ["#263748", "#1c2937"];
    return ["#18466b", "#1b3452"];
}
