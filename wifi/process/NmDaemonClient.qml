import Shelllist.Io as Io
import "../NmApi.js" as NmApi

Io.JsonlDaemonClient {
    daemonName: "nm-daemon"
    streams: NmApi.subscribedStreams
}
