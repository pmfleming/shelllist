pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Shelllist.Io as Io

// Run only by the isolated Rust socket probe: private runtime + bus, no windows,
// hardware backend, real desktop services, or mock Quickshell transport plugin.
ShellRoot {
    id: root
    readonly property string mode: Quickshell.env("SOCKET_PROBE_MODE")
    property int connections: 0
    property int failures: 0
    property bool retiring: false
    property int samples: 0
    function fail(reason) {
        console.error("SOCKET_PROBE_FAIL " + mode + " " + reason);
        Qt.exit(1);
    }
    function passed() {
        console.log("SOCKET_PROBE_PASS " + mode);
        Qt.quit();
    }
    Io.JsonlDaemonClient {
        id: client
        daemonName: "bt-daemon"
        useSocket: root.mode !== "memory-bridge"
        socketPath: Quickshell.env("SOCKET_PROBE_PATH")
        active: true
        automaticSubscribe: false
        streams: []
        recoverProtocolErrors: true
        initialRetryInterval: 100
        maximumRetryInterval: 100
        onReadyChanged: {
            if (!ready)
                return;
            root.connections++;
            if (root.mode !== "blocked") {
                call("probe", "bluetooth.snapshot", {});
                return;
            }
            if (root.connections === 1) {
                let accepted = 0;
                try {
                    for (let index = 0; index < 1000; index++) {
                        call("not-replay-" + index, "effect.once", {text: "x".repeat(65536)});
                        accepted++;
                    }
                } catch (error) {
                    if (accepted < 2 || accepted >= 64)
                        root.fail("invalid byte-window admission count " + accepted);
                }
                if (accepted === 1000)
                    root.fail("unbounded native write window");
                transportBackend.maximumPendingBytes = transportBackend.pendingBytes;
                try {
                    cancel("cancel-blocked", "not-replay-0");
                } catch (error) {
                    root.fail("full call byte budget starved control admission");
                    return;
                }
                retire.start();
            } else if (root.connections === 2) {
                call("reconnected", "probe.reconnected", {});
            } else {
                root.fail("unexpected extra reconnect");
            }
        }
        onResponse: function(id, envelope, error, route) {
            if (error) {
                root.fail("unexpected response error");
                return;
            }
            if (root.mode === "blocked") {
                if (id !== "reconnected" || root.connections !== 2 || root.failures !== 1)
                    root.fail("failed-generation traffic was replayed");
                else
                    root.passed();
                return;
            }
            if (root.mode.startsWith("memory-")) {
                if (!envelope || !envelope.ok || envelope.protocol !== "bt-api" || !envelope.data || !envelope.data.snapshot) {
                    root.fail("invalid memory-probe snapshot");
                    return;
                }
                root.samples++;
                if (root.samples < 50)
                    call("probe", "bluetooth.snapshot", {});
                else
                    restartControl.connected = true;
                return;
            }
            if (root.mode === "bluetooth" || root.mode === "restart") {
                if (!envelope || envelope.protocol !== "bt-api" || envelope.version !== 2 || !envelope.data.snapshot) {
                    root.fail("invalid real Bluetooth snapshot");
                    return;
                }
                if (root.mode === "bluetooth") {
                    root.passed();
                } else if (root.connections === 1) {
                    restartControl.connected = true;
                } else if (root.connections === 2 && envelope.data.snapshot.adapters[0].key === "restarted-generation") {
                    root.passed();
                } else {
                    root.fail("restart did not establish fresh state");
                }
                return;
            }
            const expected = root.mode === "large" ? "🦀".repeat(2 * 1024 * 1024) : "你好 🦀 café";
            if (!envelope || !envelope.data || envelope.data.text !== expected)
                root.fail("record changed across native Socket/SplitParser");
            else
                root.passed();
        }
        onTransportFailed: function(message) {
            root.failures++;
            if (root.mode === "restart")
                return;
            if (root.mode !== "blocked" || !root.retiring || root.failures !== 1)
                root.fail("unexpected transport failure: " + message);
        }
    }
    Socket {
        id: restartControl
        path: Quickshell.env("SOCKET_PROBE_CONTROL")
        onConnectionStateChanged: if (connected) write(JSON.stringify({ready: true, pid: Quickshell.processId, mode: root.mode}) + "\n")
        parser: SplitParser {
            onRead: function(line) {
                if (root.mode.startsWith("memory-") && line === "release")
                    root.passed();
            }
        }
    }
    Timer {
        id: retire
        interval: 200
        onTriggered: {
            root.retiring = true;
            client.recover("injected failed generation with a full write buffer");
        }
    }
    Timer {
        interval: 15000
        running: true
        onTriggered: root.fail("probe deadline exceeded")
    }
}
