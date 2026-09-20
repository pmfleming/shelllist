.pragma library
.import "../Bar/BarProtocol.generated.js" as Protocol

var protocol = Protocol.protocol;
var version = Protocol.version;
var methods = {
    snapshot: Protocol.methods["bar.snapshot"],
    policy: Protocol.methods["displayPolicy.set"],
    preview: Protocol.methods["displayLayout.preview"],
    confirm: Protocol.methods["displayLayout.confirm"],
    revert: Protocol.methods["displayLayout.revert"]
};
var stream = Protocol.streams["display-policy.changed"];
var subscribedStreams = [stream];
