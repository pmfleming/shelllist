#!/usr/bin/env python3
"""Start the packaged scanner, not just its reusable button. Never use host devices/buses."""
import argparse
import glob
import os
import pathlib
import shutil
import signal
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("qrca", type=pathlib.Path)
parser.add_argument("--isolated", action="store_true", help="Already inside a Nix build sandbox")
args = parser.parse_args()
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
           QT_LOGGING_RULES="qml.info=true", QT_FORCE_STDERR_LOGGING="1", QT_ASSUME_STDERR_HAS_CONSOLE="1", QT_STYLE_OVERRIDE="Fusion",
           QT_QPA_PLATFORMTHEME="", XDG_CURRENT_DESKTOP="")
for key in ("DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS", "DISPLAY", "WAYLAND_DISPLAY"):
    env.pop(key, None)
with tempfile.TemporaryDirectory(prefix="qrca-startup-") as temporary:
    env.update(HOME=temporary, XDG_CONFIG_HOME=temporary, XDG_DATA_HOME=temporary,
               XDG_CACHE_HOME=temporary, XDG_RUNTIME_DIR=temporary)
    bus_config = pathlib.Path(temporary) / "session.conf"
    bus_config.write_text('''<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen>
<auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/>
<allow receive_sender="*"/><allow own="*"/></policy></busconfig>''')
    dbus = shutil.which("dbus-run-session")
    daemon = shutil.which("dbus-daemon")
    command = [str(pathlib.Path(dbus).resolve()) if dbus else None,
               "--dbus-daemon=" + str(pathlib.Path(daemon).resolve()) if daemon else None,
               "--config-file=" + str(bus_config), "--", str(args.qrca.resolve()), "--wifi"]
    if args.isolated:
        if glob.glob("/dev/video*") or pathlib.Path("/run/dbus/system_bus_socket").exists():
            raise SystemExit("Refusing --isolated with host camera/system bus access")
    else:
        passwd = pathlib.Path(temporary) / "passwd"
        passwd.write_text(f"test:x:{os.getuid()}:{os.getgid()}:Test:{temporary}:/nonexistent\n")
        command = [shutil.which("bwrap"), "--unshare-all", "--die-with-parent",
                   "--ro-bind", "/nix/store", "/nix/store", "--proc", "/proc",
                   "--dev", "/dev", "--tmpfs", "/tmp", "--tmpfs", "/run",
                   "--dir", temporary, "--ro-bind", str(bus_config), str(bus_config),
                   "--ro-bind", str(passwd), "/etc/passwd", "--chdir", temporary, "--", *command]
    if any(part is None for part in command):
        raise SystemExit("dbus-run-session and (outside Nix builds) bwrap are required")
    with tempfile.TemporaryFile() as log:
        process = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
        try:
            # Keep running after Component.onCompleted to catch delayed startup errors.
            deadline = time.monotonic() + 30
            while process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.1)
                log.seek(0)
                if b"qrca scanner page ready" in log.read():
                    time.sleep(1)
                    break
            exited = process.poll()
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
        log.seek(0)
        output = log.read().decode(errors="replace")
    failures = ("Invalid property assignment", "TypeError:", "ReferenceError:",
                "failed to load component", "is not a type")
    if exited is not None or "qrca scanner page ready" not in output or any(s in output for s in failures):
        print(output)
        raise SystemExit(f"Packaged QR scanner failed startup (exit={exited})")
    print("Packaged QR scanner page loaded (offscreen, private bus, no camera/network)")
