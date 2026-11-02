.pragma library

function unique(values) { return [...new Set(values.filter(Boolean))]; }
function local(record) {
    return unique((record.installations || []).map(i => i.active_version || i.declared_version)).join(" / ") || "—";
}
function latest(record) {
    return unique((record.installations || []).map(i => i.release && i.release.version)).join(" / ") || "—";
}
function group(record) {
    if (record.kind === "desktop-application") {
        const categories = {shell: qsTr("Terminal"), browser: qsTr("Browsers"), code: qsTr("Development"), media: qsTr("Media"), text: qsTr("Documents")};
        return qsTr("Applications · %1").arg(categories[record.category] || qsTr("Uncategorized"));
    }
    return ({"desktop-shortcut": qsTr("Shortcuts"), "command-line": qsTr("Command-line tools"),
        "system": qsTr("System packages"), "local-helper": qsTr("Local helpers")})[record.kind] || qsTr("Other software");
}
function summary(record) {
    const releases = (record.installations || []).map(i => i.release).filter(Boolean);
    if (!releases.length) return qsTr("%1: no release source configured.").arg(record.name);
    return unique(releases.map(r => !r.version
        ? (r.error ? qsTr("%1: release check failed.").arg(record.name) : qsTr("%1: latest release not checked.").arg(record.name))
        : r.error ? qsTr("%1: last known %2; check failed.").arg(record.name).arg(r.version)
        : r.stale ? qsTr("%1: last known release %2.").arg(record.name).arg(r.version)
        : qsTr("%1: latest release %2.").arg(record.name).arg(r.version))).join(" ");
}
function icon(record) {
    const releases = (record.installations || []).map(i => i.release).filter(Boolean);
    if (releases.some(r => r.error)) return "warning";
    if (releases.some(r => r.stale && r.version)) return "history";
    return releases.some(r => r.version) ? "info" : "help_outline";
}
function details(record) {
    return (record.installations || []).map(i => {
        let text = i.scope + ": " + i.package_name;
        if (i.stale) text += qsTr(" · cached observation; source unavailable");
        if (i.active_version) text += qsTr(" · active %1").arg(i.active_version);
        if (i.declared_version) text += qsTr(" · declared %1").arg(i.declared_version);
        if (i.release) {
            text += " · " + i.release.source;
            if (i.release.checked_at) text += qsTr(" · checked %1").arg(new Date(i.release.checked_at * 1000).toLocaleString());
            if (i.release.error) text += " · " + i.release.error;
        }
        return text;
    }).join("\n");
}
