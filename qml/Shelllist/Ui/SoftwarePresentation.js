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

function releaseSourceLabel(source) {
    const value = String(source || "");
    const github = /^https:\/\/api\.github\.com\/repos\/([^/]+)\/([^/]+)\/releases\/latest\/?$/.exec(value);
    return github ? qsTr("GitHub · %1/%2").arg(github[1]).arg(github[2]) : value || qsTr("Not configured");
}

// Passive facts, built from catalog fields rather than parsing diagnostic prose.
function installationRows(record) {
    const installations = record.installations || [];
    const rows = [];
    installations.forEach((installation, index) => {
        function add(key, label, value, description) {
            rows.push({key: index + ":" + key, label: label, value: value || "—", description: description || ""});
        }
        add("package", qsTr("Package"), installation.package_name);
        const scope = String(installation.scope || "");
        add("scope", qsTr("Installed for"), scope === "system" ? qsTr("System")
            : scope.startsWith("user:") ? qsTr("User · %1").arg(scope.slice(5)) : scope);
        if (installations.length > 1)
            add("local", qsTr("Local version"), installation.active_version || installation.declared_version);
        if (installation.declared_version && installation.active_version && installation.declared_version !== installation.active_version)
            add("declared", qsTr("Declared version"), installation.declared_version);
        if (installation.stale)
            add("observation", qsTr("Observation"), qsTr("Cached; source unavailable"));
        const release = installation.release || {};
        if (installations.length > 1)
            add("latest", qsTr("Latest version"), release.version);
        add("source", qsTr("Release source"), releaseSourceLabel(release.source), release.source);
        const checked = release.checked_at ? new Date(release.checked_at * 1000) : null;
        add("checked", qsTr("Last checked"), checked ? Qt.formatDateTime(checked, "d MMM yyyy, HH:mm") : qsTr("Not checked"),
            checked ? checked.toLocaleString() : "");
        if (release.error)
            add("status", qsTr("Release check"), release.error);
        else if (release.stale)
            add("status", qsTr("Release check"), qsTr("Cached release information"));
    });
    return rows.length ? rows : [{key: "missing", label: qsTr("Package"), value: qsTr("No package information reported"), description: ""}];
}
