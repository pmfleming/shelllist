.pragma library

function iconName(code, isDay) {
    const value = Number(code);
    const daytime = isDay === undefined || isDay === null ? true : !!isDay;
    if (value === 0)
        return daytime ? "clear-day" : "clear-night";
    if (value === 1 || value === 2)
        return daytime ? "partly-cloudy-day" : "partly-cloudy-night";
    if (value === 3)
        return daytime ? "overcast-day" : "overcast-night";
    if (value === 45 || value === 48)
        return daytime ? "fog-day" : "fog-night";
    if (value >= 51 && value <= 57)
        return "drizzle";
    if ((value >= 61 && value <= 67) || (value >= 80 && value <= 82))
        return "rain";
    if ((value >= 71 && value <= 77) || value === 85 || value === 86)
        return "snow";
    if (value >= 95 && value <= 99)
        return daytime ? "thunderstorms-day" : "thunderstorms-night";
    return "not-available";
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
