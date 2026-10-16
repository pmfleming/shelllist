#!/usr/bin/env python3
"""Actual Qt/QProcess tests for Qrca's nm-daemon delegation; synthetic data only."""
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

header = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="qrca-credentials-") as directory:
    root = Path(directory)
    (root / "NmWifiConnection.h").write_bytes(header.read_bytes())
    (root / "main.cpp").write_text(r'''
#include <QCoreApplication>
#include "NmWifiConnection.h"
int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    bool called = false;
    const bool expected = qEnvironmentVariable("CASE") == QStringLiteral("success") || qEnvironmentVariable("CASE") == QStringLiteral("early");
    nmWifiConnect(&app, QStringLiteral("WIFI:T:WPA;S:Fixture;P:synthetic-test-only;;"),
        qEnvironmentVariable("REMEMBER") == QStringLiteral("1"), [&](bool ok) {
            if (called || ok != expected) app.exit(2);
            else { called = true; app.exit(0); }
        });
    QTimer::singleShot(5000, &app, [&] { app.exit(3); });
    return app.exec();
}
''')
    mock = root / "nm-daemon"
    mock.write_text("#!" + sys.executable + "\n" + r'''
import json, os, sys, select
assert sys.argv[1:] == ["client"], "credentials must not be process arguments"
def send(value):
    print(json.dumps(value), flush=True)
def reply(id, data):
    send({"kind":"response", "id":id, "ok":True, "response":{"protocol":"nm-api", "version":2, "ok":True, "data":data}})
subscribe = json.loads(sys.stdin.readline())
assert subscribe["op"] == "subscribe" and subscribe["streams"] == ["wifi.connect"]
reply("subscribe", {"subscription":{"id":"sub"}})
request = json.loads(sys.stdin.readline())
assert request["method"] == "wifi.qr.connect"
assert request["params"] == {"payload":"WIFI:T:WPA;S:Fixture;P:synthetic-test-only;;", "remember":os.environ["REMEMBER"] == "1"}
case = os.environ["CASE"]
event = {"protocol":"nm-api", "version":2, "request_id":"request", "event":"succeeded" if case in ("success", "early") else "failed", "data":{"result":{"status":"connected"}}}
if case == "malformed":
    print("not json", flush=True)
elif case == "transport":
    send({"kind":"transport-error", "error":"fixture owner changed"})
elif case == "rejected":
    send({"kind":"response", "id":"connect", "ok":True, "response":{"protocol":"nm-api", "version":2, "ok":False}})
elif case == "missing-id":
    reply("connect", {"result":{}})
else:
    if case == "early": send({"kind":"event", "stream":"wifi.connect", "event":event})
    reply("connect", {"result":{"request_id":"request"}})
    # Duplicate subscription replies must not submit the credentials again.
    reply("subscribe", {"subscription":{"id":"sub"}})
    if case != "early": assert not select.select([sys.stdin], [], [], 0.05)[0], "automatic replay is forbidden"
    send({"kind":"event", "stream":"wifi.connect", "event":dict(event, request_id="unrelated")})
    if case != "early": send({"kind":"event", "stream":"wifi.connect", "event":event})
assert not sys.stdin.readline(), "automatic replay is forbidden"
''')
    mock.chmod(0o700)
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "Qt6Core"], text=True))
    subprocess.run([os.environ.get("CXX", "c++"), "-std=c++17", "-fPIC", "-DQT_NO_CAST_FROM_ASCII", "-DQT_NO_CAST_TO_ASCII", "-I" + str(root), str(root / "main.cpp"), "-o", str(root / "test"), *flags], check=True)
    for case in ["success", "early", "failed", "malformed", "transport", "rejected", "missing-id"]:
        for remember in ["0", "1"]:
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"], CASE=case, REMEMBER=remember)
            subprocess.run([str(root / "test")], env=env, check=True, timeout=8)
    print("PASS Qrca native Qt: remember on/off, stdin-only secrets, correlated completion, early events, no replay and fail-closed transport")
