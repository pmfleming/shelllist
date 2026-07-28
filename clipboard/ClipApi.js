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
    captureScreenshot: "clipboard.capture.screenshot",
    selectionPublishFiles: "clipboard.selection.publishFiles",
    settingsGet: "clipboard.settings.get",
    settingsUpdate: "clipboard.settings.update",
    wipePrepare: "clipboard.history.wipe.prepare",
    wipeCommit: "clipboard.history.wipe.commit"
};

function actionsForKind(kind) {
    const common = ["paste", "copy"];
    if (kind === "text")
        return ["paste", "edit-external"];
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
    paste: "Paste", copy: "Copy", edit: "Edit", "edit-external": "Edit", "open-url": "Open URL",
    "image-as-file": "Paste as file", annotate: "Edit",
    "open-file": "Open file", "reveal-file": "Reveal file"
};

function actionDescriptorsForKind(kind) {
    return actionsForKind(kind).map(function (actionId) {
        return {
            id: actionId,
            label: actionLabels[actionId],
            role: actionId === "paste" ? "default" : "secondary"
        };
    });
}
