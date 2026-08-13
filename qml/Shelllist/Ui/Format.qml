pragma Singleton

import QtQuick

QtObject {
    function bytes(value: var): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let size = Math.max(0, Number(value) || 0);
        let unit = 0;
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024;
            unit += 1;
        }
        return (unit > 0 && size < 10 ? size.toFixed(1) : Math.round(size)).toString().replace(/\.0$/, "")
            + " " + units[unit];
    }

    function duration(value: var): string {
        const seconds = Math.max(0, Math.round(Number(value) || 0));
        if (seconds === 0) return "No timeout";
        if (seconds < 60) return seconds + " sec";
        const minutes = Math.floor(seconds / 60);
        return minutes + "m" + (seconds % 60 > 0 ? " " + (seconds % 60) + "s" : "");
    }
}
