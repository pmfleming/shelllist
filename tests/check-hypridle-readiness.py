#!/usr/bin/env python3
"""Readiness tests without a compositor, logind calls, or suspend operations."""
import os
import pathlib
import socket
import subprocess
import sys
import tempfile

hypridle, probe = sys.argv[1:]
with tempfile.TemporaryDirectory() as root:
    root = pathlib.Path(root)
    for abstract in (False, True):
        address = str(root / "notify") if not abstract else "\0shelllist-ready-" + str(os.getpid())
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as server:
            server.bind(address)
            server.settimeout(1)
            env = dict(os.environ, NOTIFY_SOCKET=("@" + address[1:] if abstract else address))
            subprocess.run([probe], env=env, check=True)
            assert server.recv(4096).startswith(b"READY=1\n"), "native handshake missing"
        if not abstract:
            os.unlink(address)

    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as server:
        address = str(root / "failure-notify")
        server.bind(address)
        server.settimeout(0.05)
        # Both parser errors and postParse listener-validation errors must fail
        # before connecting to a display or advertising readiness.
        for text in ("general {\n unknown_setting = 123\n}\n", "general {\n}\n"):
            config = root / "hypr" / "hypridle.conf"
            config.parent.mkdir(exist_ok=True)
            config.write_text(text)
            env = dict(os.environ, NOTIFY_SOCKET=address, BAR_DAEMON_IDLE_MANAGED="1",
                       XDG_CONFIG_HOME=str(root), HOME=str(root),
                       XDG_RUNTIME_DIR=str(root), WAYLAND_DISPLAY="nonexistent")
            result = subprocess.run([hypridle, "--config", str(config)], env=env,
                                    capture_output=True, text=True, timeout=3)
            assert result.returncode != 0
            output = result.stdout + result.stderr
            assert "Managed hypridle" in output, output
            try:
                data = server.recv(4096)
                raise AssertionError(f"invalid config announced readiness: {data!r}")
            except TimeoutError:
                pass
print("hypridle readiness: native Unix socket handshake and invalid-config rejection passed")
