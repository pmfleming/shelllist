import Shelllist.Io as Io
import "ClipApi.js" as ClipApi

Io.JsonlDaemonClient {
    daemonName: "clip-daemon"
    recoverProtocolErrors: true
    streams: [
        ClipApi.streams.history,
        ClipApi.streams.current,
        ClipApi.streams.operation,
        ClipApi.streams.capture,
        ClipApi.streams.session
    ]
}
