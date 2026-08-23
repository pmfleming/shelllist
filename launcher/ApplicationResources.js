.pragma library

function finite(value) {
    const number = Number(value);
    return isFinite(number) ? number : 0;
}

function decimal(value, digits) {
    return finite(value).toFixed(digits === undefined ? 1 : digits);
}

function integer(value) {
    return Math.round(finite(value)).toLocaleString();
}

function percent(value) {
    return decimal(value, 1) + "%";
}

function ratioPercent(value) {
    return decimal(finite(value) * 100, 1) + "%";
}

function bytes(value) {
    const amount = Math.max(0, finite(value));
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let scaled = amount;
    let unit = 0;
    while (scaled >= 1024 && unit < units.length - 1) {
        scaled /= 1024;
        unit += 1;
    }
    const digits = unit === 0 ? 0 : scaled >= 100 ? 0 : 1;
    return scaled.toFixed(digits) + " " + units[unit];
}

function rate(value) {
    return bytes(value) + "/s";
}

function operationsRate(value) {
    return decimal(value, 1) + " ops/s";
}

function energy(value) {
    const amount = Math.max(0, finite(value));
    return amount >= 1000 ? decimal(amount / 1000, 2) + " Wh" : decimal(amount, 2) + " mWh";
}

function power(value) {
    return decimal(value, 2) + " W";
}

function duration(value) {
    const milliseconds = Math.max(0, finite(value));
    return milliseconds >= 1000 ? decimal(milliseconds / 1000, 1) + " s" : integer(milliseconds) + " ms";
}

function text(value, fallback) {
    const result = String(value === undefined || value === null ? "" : value).trim();
    return result || fallback || "Unavailable";
}

function availability(value) {
    return value ? "Available" : "Unavailable";
}

function field(key, label, value) {
    return { key: key, label: label, value: value };
}

function computeFields(resource) {
    return [
        field("cpu_percent", "CPU · logical cores", percent(resource.cpu_percent)),
        field("cpu_percent_of_machine", "CPU · whole machine", percent(resource.cpu_percent_of_machine)),
        field("memory_bytes", "Memory · best estimate", bytes(resource.memory_bytes)),
        field("memory_rss_bytes", "Memory · RSS", bytes(resource.memory_rss_bytes)),
        field("memory_pss_bytes", "Memory · PSS", bytes(resource.memory_pss_bytes)),
        field("memory_private_bytes", "Memory · private", bytes(resource.memory_private_bytes)),
        field("memory_swap_bytes", "Memory · swap", bytes(resource.memory_swap_bytes)),
        field("memory_cgroup_bytes", "Memory · cgroup", bytes(resource.memory_cgroup_bytes)),
        field("process_count", "Processes", integer(resource.process_count)),
        field("thread_count", "Threads", integer(resource.thread_count)),
        field("major_faults_per_second", "Major faults", decimal(resource.major_faults_per_second, 2) + "/s"),
        field("gpu_percent", "GPU · aggregate engines", percent(resource.gpu_percent)),
        field("gpu_busy_percent", "GPU · busiest engine", percent(resource.gpu_busy_percent)),
        field("gpu_memory_bytes", "GPU memory · best estimate", bytes(resource.gpu_memory_bytes)),
        field("gpu_memory_resident_bytes", "GPU memory · resident", bytes(resource.gpu_memory_resident_bytes)),
        field("gpu_memory_allocated_bytes", "GPU memory · allocated", bytes(resource.gpu_memory_allocated_bytes))
    ];
}

function storageFields(resource) {
    return [
        field("disk_read_bytes", "Physical reads · interval", bytes(resource.disk_read_bytes)),
        field("disk_write_bytes", "Physical writes · interval", bytes(resource.disk_write_bytes)),
        field("disk_read_bytes_per_second", "Physical read rate", rate(resource.disk_read_bytes_per_second)),
        field("disk_write_bytes_per_second", "Physical write rate", rate(resource.disk_write_bytes_per_second)),
        field("logical_read_bytes", "Logical reads · interval", bytes(resource.logical_read_bytes)),
        field("logical_write_bytes", "Logical writes · interval", bytes(resource.logical_write_bytes)),
        field("logical_read_bytes_per_second", "Logical read rate", rate(resource.logical_read_bytes_per_second)),
        field("logical_write_bytes_per_second", "Logical write rate", rate(resource.logical_write_bytes_per_second)),
        field("read_operations", "Read operations · interval", integer(resource.read_operations)),
        field("write_operations", "Write operations · interval", integer(resource.write_operations)),
        field("read_operations_per_second", "Read operation rate", operationsRate(resource.read_operations_per_second)),
        field("write_operations_per_second", "Write operation rate", operationsRate(resource.write_operations_per_second)),
        field("cancelled_write_bytes", "Cancelled writes", bytes(resource.cancelled_write_bytes)),
        field("open_file_disk_bytes", "Open-file footprint", bytes(resource.open_file_disk_bytes)),
        field("referenced_file_disk_bytes", "Referenced-file footprint", bytes(resource.referenced_file_disk_bytes)),
        field("referenced_file_temporary_bytes", "Referenced temporary files", bytes(resource.referenced_file_temporary_bytes)),
        field("referenced_file_permanent_bytes", "Referenced permanent files", bytes(resource.referenced_file_permanent_bytes)),
        field("disk_space_total_bytes", "Application data · total", bytes(resource.disk_space_total_bytes)),
        field("disk_space_temporary_bytes", "Application data · temporary", bytes(resource.disk_space_temporary_bytes)),
        field("disk_space_permanent_bytes", "Application data · permanent", bytes(resource.disk_space_permanent_bytes))
    ];
}

function networkFields(resource) {
    return [
        field("network_receive_bytes", "Network received · interval", bytes(resource.network_receive_bytes)),
        field("network_transmit_bytes", "Network transmitted · interval", bytes(resource.network_transmit_bytes)),
        field("network_receive_bytes_per_second", "Network receive rate", rate(resource.network_receive_bytes_per_second)),
        field("network_transmit_bytes_per_second", "Network transmit rate", rate(resource.network_transmit_bytes_per_second)),
        field("network_connection_count", "Network connections", integer(resource.network_connection_count))
    ];
}

function currentEnergyFields(resource) {
    return [
        field("energy_mwh", "Attributed energy · interval", energy(resource.energy_mwh)),
        field("battery_percent", "Attributed battery · interval", percent(resource.battery_percent)),
        field("power_watts", "Estimated power · compatibility", power(resource.power_watts)),
        field("estimated_app_power_watts", "Estimated application power", power(resource.estimated_app_power_watts)),
        field("system_power_watts", "System power context", power(resource.system_power_watts)),
        field("battery_percent_per_hour", "Estimated battery rate", percent(resource.battery_percent_per_hour) + "/h"),
        field("attributed_fraction", "Attributed CPU-energy share", ratioPercent(resource.attributed_fraction)),
        field("energy_source", "Energy source", text(resource.energy_source)),
        field("energy_confidence", "Energy confidence", text(resource.energy_confidence))
    ];
}

function historicalEnergyFields(resource) {
    return [
        field("energy_mwh", "Attributed energy · bucket", energy(resource.energy_mwh)),
        field("battery_percent", "Attributed battery · bucket", percent(resource.battery_percent)),
        field("average_power_watts", "Average application power", power(resource.average_power_watts)),
        field("system_power_watts", "Average system power", power(resource.system_power_watts)),
        field("attributed_fraction", "Attributed CPU-energy share", ratioPercent(resource.attributed_fraction)),
        field("energy_source", "Energy source", text(resource.energy_source)),
        field("energy_confidence", "Energy confidence", text(resource.energy_confidence))
    ];
}

function measurementFields(resource) {
    const measurement = resource.measurement || ({});
    return [
        field("measurement.sample_interval_ms", "Sample interval", duration(measurement.sample_interval_ms)),
        field("measurement.attribution_method", "Attribution method", text(measurement.attribution_method)),
        field("measurement.coverage", "Process coverage", ratioPercent(measurement.coverage)),
        field("measurement.memory_source", "Memory source", text(measurement.memory_source)),
        field("measurement.gpu_available", "GPU accounting", availability(measurement.gpu_available)),
        field("measurement.storage_available", "Storage accounting", availability(measurement.storage_available)),
        field("measurement.disk_space_scope", "Application-data scope", text(measurement.disk_space_scope)),
        field("measurement.network_available", "Network inspection", availability(measurement.network_available)),
        field("measurement.network_bytes_available", "Network byte accounting", availability(measurement.network_bytes_available)),
        field("measurement.network_connections_available", "Network connections", availability(measurement.network_connections_available)),
        field("measurement.resources_shared", "Resources shared", measurement.resources_shared ? "Yes" : "No")
    ];
}

function historyFields(resource) {
    const peaks = resource.peaks || ({});
    return [
        field("timestamp_ms", "Bucket timestamp", resource.timestamp_ms ? new Date(resource.timestamp_ms).toLocaleString() : "Unavailable"),
        field("duration_ms", "Observed duration", duration(resource.duration_ms)),
        field("sample_count", "Samples", integer(resource.sample_count)),
        field("coverage", "Average coverage", ratioPercent(resource.coverage)),
        field("peaks.cpu_percent", "Peak CPU · logical cores", percent(peaks.cpu_percent)),
        field("peaks.cpu_percent_of_machine", "Peak CPU · whole machine", percent(peaks.cpu_percent_of_machine)),
        field("peaks.memory_bytes", "Peak memory", bytes(peaks.memory_bytes)),
        field("peaks.gpu_percent", "Peak GPU · aggregate", percent(peaks.gpu_percent)),
        field("peaks.gpu_busy_percent", "Peak GPU · busiest engine", percent(peaks.gpu_busy_percent)),
        field("peaks.disk_read_bytes_per_second", "Peak physical read rate", rate(peaks.disk_read_bytes_per_second)),
        field("peaks.disk_write_bytes_per_second", "Peak physical write rate", rate(peaks.disk_write_bytes_per_second)),
        field("peaks.estimated_app_power_watts", "Peak application power", power(peaks.estimated_app_power_watts))
    ];
}

function detailGroups(resource, historical) {
    const value = resource || ({});
    const groups = [
        { title: "Compute and memory", fields: computeFields(value) },
        { title: "Storage and files", fields: storageFields(value) },
        { title: "Network", fields: networkFields(value) },
        { title: "Energy", fields: historical ? historicalEnergyFields(value) : currentEnergyFields(value) }
    ];
    if (historical)
        groups.push({ title: "History quality and peaks", fields: historyFields(value) });
    else
        groups.push({ title: "Measurement and capabilities", fields: measurementFields(value) });
    return groups;
}

function currentMetadataBadges(application) {
    const measurement = application.measurement || ({});
    const badges = [
        { text: text(measurement.attribution_method, "Unknown attribution"), tone: "accent" },
        { text: ratioPercent(measurement.coverage) + " coverage", tone: measurement.coverage < 0.8 ? "warning" : "normal" },
        { text: duration(measurement.sample_interval_ms) + " samples", tone: "normal" },
        { text: text(measurement.memory_source, "Unknown memory").toUpperCase() + " memory", tone: "normal" },
        { text: "Energy " + text(application.energy_confidence).toLowerCase(), tone: application.energy_confidence === "low" ? "warning" : "normal" }
    ];
    if (measurement.resources_shared)
        badges.push({ text: "Shared attribution", tone: "warning" });
    return badges;
}

function historicalMetadataBadges(latestPoint) {
    return [
        { text: "Retained history", tone: "accent" },
        { text: ratioPercent(latestPoint.coverage) + " coverage", tone: latestPoint.coverage < 0.8 ? "warning" : "normal" },
        { text: integer(latestPoint.sample_count) + " samples", tone: "normal" },
        { text: "Energy " + text(latestPoint.energy_confidence).toLowerCase(), tone: latestPoint.energy_confidence === "low" ? "warning" : "normal" }
    ];
}

function metadataBadges(application, latestPoint) {
    if (application && application.running)
        return currentMetadataBadges(application);
    return latestPoint ? historicalMetadataBadges(latestPoint) : [];
}
