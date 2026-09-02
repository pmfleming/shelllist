.pragma library
.import "ClipProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;

var streams = {
    history: Protocol.streams["clipboard.history.changed"],
    current: Protocol.streams["clipboard.current.changed"],
    operation: Protocol.streams["clipboard.operation"],
    capture: Protocol.streams["clipboard.capture.changed"],
    session: Protocol.streams["clipboard.session"]
};

var subscribedStreams = Object.keys(streams).map(function (name) { return streams[name]; });

var methods = {
    sessionBegin: Protocol.methods["clipboard.session.begin"],
    sessionEnd: Protocol.methods["clipboard.session.end"],
    sessionHidden: Protocol.methods["clipboard.session.hidden"],
    historyQuery: Protocol.methods["clipboard.history.query"],
    historyRevision: Protocol.methods["clipboard.history.revision"],
    entryDetails: Protocol.methods["clipboard.entry.details"],
    entryThumbnail: Protocol.methods["clipboard.entry.thumbnail"],
    entryAction: Protocol.methods["clipboard.entry.action"],
    editBegin: Protocol.methods["clipboard.entry.edit.begin"],
    editCommit: Protocol.methods["clipboard.entry.edit.commit"],
    editCancel: Protocol.methods["clipboard.entry.edit.cancel"],
    captureSetPaused: Protocol.methods["clipboard.capture.setPaused"],
    captureScreenshot: Protocol.methods["clipboard.capture.screenshot"],
    selectionPublishText: Protocol.methods["clipboard.selection.publishText"],
    selectionPublishFiles: Protocol.methods["clipboard.selection.publishFiles"],
    settingsGet: Protocol.methods["clipboard.settings.get"],
    settingsUpdate: Protocol.methods["clipboard.settings.update"],
    wipePrepare: Protocol.methods["clipboard.history.wipe.prepare"],
    wipeCommit: Protocol.methods["clipboard.history.wipe.commit"]
};

function actionsForKind(kind) {
    const common = ["paste", "copy"];
    if (kind === "text")
        return ["paste"];
    if (["html", "json", "color"].indexOf(kind) >= 0)
        return common.concat(["edit"]);
    if (kind === "link")
        return common.concat(["edit", "open-url"]);
    if (kind === "image")
        return ["paste", "image-as-file", "annotate"];
    if (kind === "files")
        return common.concat(["open-file", "reveal-file"]);
    return ["copy"];
}

var actionLabels = {
    paste: "Paste", copy: "Copy", edit: "Edit", "open-url": "Open URL",
    "image-as-file": "Paste as file", annotate: "Edit",
    "open-file": "Open file", "reveal-file": "Reveal file"
};

function actionDescriptorsForKind(kind) {
    const primaryId = kind === "binary" ? "copy" : "paste";
    return actionsForKind(kind).map(function (actionId) {
        const primary = actionId === primaryId;
        return {
            id: actionId,
            label: actionLabels[actionId],
            role: primary ? "default" : "secondary",
            presentation: { group: primary ? "primary" : "toolbar" }
        };
    });
}
