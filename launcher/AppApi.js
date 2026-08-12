.pragma library

var protocol = "app-api";
var version = 1;
var methods = ({
    query: "applications.query",
    history: "applications.history",
    refresh: "applications.refresh",
    execute: "applications.execute"
});
var streams = ({
    applications: "applications.changed",
    windows: "windows.changed",
    operation: "applications.operation"
});
