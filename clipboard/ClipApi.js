.pragma library

var streams = {
    history: "clipboard.history.changed",
    current: "clipboard.current.changed",
    operation: "clipboard.operation",
    capture: "clipboard.capture.changed",
    session: "clipboard.session"
};

var methods = {
    sessionBegin: "clipboard.session.begin",
    sessionEnd: "clipboard.session.end",
    sessionHidden: "clipboard.session.hidden",
    historyQuery: "clipboard.history.query",
    entryDetails: "clipboard.entry.details",
    entryThumbnail: "clipboard.entry.thumbnail",
    entryAction: "clipboard.entry.action",
    editBegin: "clipboard.entry.edit.begin",
    editCommit: "clipboard.entry.edit.commit",
    editCancel: "clipboard.entry.edit.cancel",
    captureSetPaused: "clipboard.capture.setPaused",
    settingsGet: "clipboard.settings.get",
    settingsUpdate: "clipboard.settings.update",
    wipePrepare: "clipboard.history.wipe.prepare",
    wipeCommit: "clipboard.history.wipe.commit"
};

function actionsForKind(kind) {
    const common = ["paste", "copy"];
    if (["text", "html", "json", "color"].indexOf(kind) >= 0)
        return common.concat(["edit"]);
    if (kind === "link")
        return common.concat(["edit", "open-url"]);
    if (kind === "image")
        return common.concat(["image-as-file", "annotate"]);
    if (kind === "files")
        return common.concat(["open-file", "reveal-file"]);
    return ["copy"];
}

function compatibilityError(envelope) {
    return (!envelope || envelope.protocol !== "clip-api" || envelope.version !== 1)
        ? "clip-daemon returned an incompatible response" : "";
}

function responseError(envelope, transportError) {
    if (transportError)
        return transportError;
    const compatibility = compatibilityError(envelope);
    if (compatibility)
        return compatibility;
    return envelope.ok ? "" : ((envelope.error && envelope.error.message) || "Clipboard operation failed");
}
