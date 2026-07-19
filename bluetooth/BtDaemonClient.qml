import Shelllist.Io as Io
import "BtApi.js" as BtApi

Io.JsonlDaemonClient {
    daemonName: "bt-daemon"
    recoverProtocolErrors: true
    streams: [
        BtApi.streams.changed,
        BtApi.streams.pairing,
        BtApi.streams.operation,
        BtApi.streams.scan,
        BtApi.streams.audio,
        BtApi.streams.obex
    ]
}
