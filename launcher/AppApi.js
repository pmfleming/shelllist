.pragma library

var protocol = "app-api";
var version = 1;
var methods = ({
    query: "applications.query",
    revision: "applications.revision",
    history: "applications.history",
    energyOverview: "applications.energyOverview",
    refresh: "applications.refresh",
    execute: "applications.execute",
    settingsUpdate: "applications.settings.update"
});
var streams = ({
    applications: "applications.changed",
    windows: "windows.changed",
    operation: "applications.operation"
});
