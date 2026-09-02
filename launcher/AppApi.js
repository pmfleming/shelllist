.pragma library
.import "AppProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;
var methods = ({
    query: Protocol.methods["applications.query"],
    revision: Protocol.methods["applications.revision"],
    history: Protocol.methods["applications.history"],
    energyOverview: Protocol.methods["applications.energyOverview"],
    refresh: Protocol.methods["applications.refresh"],
    execute: Protocol.methods["applications.execute"],
    settingsUpdate: Protocol.methods["applications.settings.update"]
});
var streams = ({
    applications: Protocol.streams["applications.changed"],
    windows: Protocol.streams["windows.changed"],
    operation: Protocol.streams["applications.operation"]
});
