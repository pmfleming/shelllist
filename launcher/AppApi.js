.pragma library
.import "AppProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;
// Expose the same generated boundary through the Launcher QML module as well
// as relative imports (native entrypoints have an isolated configuration root).
var requestError = Protocol.requestError;
var eventError = Protocol.eventError;
var methods = ({
        query: Protocol.methods["applications.query"],
        revision: Protocol.methods["applications.revision"],
        history: Protocol.methods["applications.history"],
        energyOverview: Protocol.methods["applications.energyOverview"],
        refresh: Protocol.methods["applications.refresh"],
        execute: Protocol.methods["applications.execute"],
        operationStatus: Protocol.methods["applications.operation.status"],
        settingsUpdate: Protocol.methods["applications.settings.update"]
    });
var streams = ({
        applications: Protocol.streams["applications.changed"],
        windows: Protocol.streams["windows.changed"],
        operation: Protocol.streams["applications.operation"]
    });
var subscribedStreams = Object.keys(streams).map(function (name) {
    return streams[name];
});
