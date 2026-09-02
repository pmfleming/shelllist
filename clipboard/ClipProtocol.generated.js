.pragma library

// Generated from the daemon-owned protocol registry. Do not edit.
var protocol = "clip-api";
var version = 1;
var methods = ({
    "clipboard.session.begin": "clipboard.session.begin",
    "clipboard.session.end": "clipboard.session.end",
    "clipboard.session.hidden": "clipboard.session.hidden",
    "clipboard.history.query": "clipboard.history.query",
    "clipboard.history.revision": "clipboard.history.revision",
    "clipboard.entry.details": "clipboard.entry.details",
    "clipboard.entry.thumbnail": "clipboard.entry.thumbnail",
    "clipboard.entry.action": "clipboard.entry.action",
    "clipboard.entry.edit.begin": "clipboard.entry.edit.begin",
    "clipboard.entry.edit.commit": "clipboard.entry.edit.commit",
    "clipboard.entry.edit.cancel": "clipboard.entry.edit.cancel",
    "clipboard.capture.setPaused": "clipboard.capture.setPaused",
    "clipboard.capture.screenshot": "clipboard.capture.screenshot",
    "clipboard.selection.publishText": "clipboard.selection.publishText",
    "clipboard.selection.publishFiles": "clipboard.selection.publishFiles",
    "clipboard.settings.get": "clipboard.settings.get",
    "clipboard.settings.update": "clipboard.settings.update",
    "clipboard.history.wipe.prepare": "clipboard.history.wipe.prepare",
    "clipboard.history.wipe.commit": "clipboard.history.wipe.commit",
});
var streams = ({
    "clipboard.history.changed": "clipboard.history.changed",
    "clipboard.current.changed": "clipboard.current.changed",
    "clipboard.operation": "clipboard.operation",
    "clipboard.capture.changed": "clipboard.capture.changed",
    "clipboard.session": "clipboard.session",
});
