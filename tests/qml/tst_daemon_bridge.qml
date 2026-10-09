pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io

TestCase {
    id: testCase
    name: "DaemonBridge"
    when: windowShown

    Component {
        id: bridgeFactory
        Io.JsonlDaemonClient {
            daemonName: "test-daemon"
            streams: []
            active: false
            automaticSubscribe: false
            recoverProtocolErrors: true
            property int failures: 0
            property int replies: 0
            onTransportFailed: failures++
            onResponse: replies++
        }
    }

    function fixture() {
        const bridge = createTemporaryObject(bridgeFactory, testCase);
        verify(bridge !== null);
        const process = findChild(bridge, "daemonBridgeProcess");
        verify(process !== null);
        process.simulated = true;
        return {bridge: bridge, process: process};
    }

    function exitProcess(f, code) {
        f.process.running = false;
        f.process.exited(code);
    }

    function test_reopenDuringDrain_data() {
        return [
            {tag: "running", starting: false},
            {tag: "starting", starting: true}
        ];
    }

    function test_reopenDuringDrain(data) {
        const f = fixture();
        f.bridge.active = true;
        compare(f.bridge.lifecycle, "starting");
        if (!data.starting)
            f.process.started();
        f.bridge.active = false;
        compare(f.bridge.lifecycle, "stopping");
        verify(!f.bridge.ready);
        verify(!f.process.stdinEnabled);
        f.bridge.active = true;
        f.bridge.call("new-effect", "effect.once", {});
        if (data.starting)
            f.process.started();
        compare(f.process.commands.length, 1);
        compare(f.process.writes.length, 0, "never write to the closing pipe");
        compare(f.bridge.queuedLines.length, 1);
        // Accepted requests still settle while the Rust client drains.
        f.bridge.handleLine(JSON.stringify({kind: "response", id: "old-call", ok: true, response: {ok: true}}));
        compare(f.bridge.replies, 1);
        exitProcess(f, 0);
        compare(f.process.commands.length, 2, "replacement starts without error backoff");
        f.process.started();
        verify(f.bridge.ready);
        compare(f.bridge.lifecycle, "running");
        compare(f.process.writes.length, 1);
        compare(JSON.parse(f.process.writes[0]).id, "new-effect");
        compare(f.bridge.failures, 0);
        f.bridge.active = false;
        exitProcess(f, 0);
        compare(f.process.commands.length, 2, "no replacement while closed");
    }

    function test_repeatedCloseDropsUnsentEffects() {
        const f = fixture();
        f.bridge.active = true;
        f.process.started();
        f.bridge.active = false;
        f.bridge.active = true;
        f.bridge.call("discard", "effect.once", {});
        f.bridge.active = false;
        exitProcess(f, 0);
        f.bridge.active = true;
        f.process.started();
        compare(f.process.writes.length, 0);
        compare(f.bridge.failures, 0);
    }

    function test_unexpectedExit_data() {
        return [{tag: "clean-but-unsolicited", code: 0}, {tag: "failed", code: 1}];
    }

    function test_unexpectedExit(data) {
        const f = fixture();
        f.bridge.active = true;
        f.process.started();
        exitProcess(f, data.code);
        compare(f.bridge.failures, 1);
        verify(!f.bridge.ready);
        compare(f.bridge.counters.retryAttempt, 1);
        f.bridge.active = false;
    }

    function test_failedDrainIsNotSilenced() {
        const f = fixture();
        f.bridge.active = true;
        f.process.started();
        f.bridge.active = false;
        f.bridge.active = true;
        f.bridge.call("never-replay", "effect.once", {});
        exitProcess(f, 1);
        compare(f.bridge.failures, 1);
        compare(f.bridge.queuedLines.length, 0);
        f.bridge.active = false;
    }

    function test_closeFromReadyNotification() {
        const f = fixture();
        f.bridge.readyChanged.connect(function () {
            if (f.bridge.ready)
                f.bridge.active = false;
        });
        f.bridge.automaticSubscribe = true;
        f.bridge.active = true;
        f.process.started();
        compare(f.bridge.lifecycle, "stopping");
        verify(!f.bridge.ready);
        compare(f.process.writes.length, 0);
        compare(f.bridge.queuedLines.length, 0);
        exitProcess(f, 0);
        compare(f.bridge.failures, 0);
    }
}
