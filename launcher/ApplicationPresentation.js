.pragma library

function finiteNumber(value) {
    const number = Number(value || 0);
    return isFinite(number) && number > 0 ? number : 0;
}

function cpuText(value) {
    const cpu = finiteNumber(value);
    return (Math.round(cpu * 10) / 10).toFixed(1) + "%";
}

function memoryText(value) {
    const bytes = finiteNumber(value);
    const mib = bytes / (1024 * 1024);
    if (mib >= 1024)
        return (Math.round(mib / 1024 * 10) / 10).toFixed(1) + " GiB";
    if (mib >= 100)
        return Math.round(mib) + " MiB";
    return (Math.round(mib * 10) / 10).toFixed(1) + " MiB";
}

function usageText(value) {
    const usage = value || ({});
    return "CPU " + cpuText(usage.cpu_percent) + " · " + memoryText(usage.memory_bytes);
}

function rateText(value) {
    const bytes = finiteNumber(value);
    if (bytes >= 1024 * 1024 * 1024)
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB/s";
    if (bytes >= 1024 * 1024)
        return (bytes / (1024 * 1024)).toFixed(1) + " MiB/s";
    if (bytes >= 1024)
        return (bytes / 1024).toFixed(1) + " KiB/s";
    return Math.round(bytes) + " B/s";
}

function powerText(value) {
    return finiteNumber(value).toFixed(2) + " W";
}

function runningWindowIcon(instanceCount) {
    return Number(instanceCount || 0) > 1 ? "󰖲" : "󰖯";
}
