#!/usr/bin/env python3
"""Real Qt -> JSONL -> app-daemon journey; no host bus, launch or compositor effects."""
import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--app-daemon", required=True, type=Path)
parser.add_argument("--search", required=True, type=Path)
parser.add_argument("--quickshell", default="quickshell")
parser.add_argument("--source-root", type=Path, default=ROOT)
args = parser.parse_args()
ROOT = args.source_root.resolve()


class NativeApplicationTests(unittest.TestCase):
    def test_search_settings_failed_launch_and_explicit_retry(self):
        with tempfile.TemporaryDirectory(prefix="shelllist-e2e-") as directory:
            root = Path(directory)
            for name in ("bin", "data/applications", "config", "state", "cache", "run", "empty"):
                (root / name).mkdir(parents=True, mode=0o700)
            for name, source in (("app-daemon", args.app_daemon), ("shelllist-search", args.search)):
                source = source.resolve(strict=True)
                (root / "bin" / name).symlink_to(source)
            launcher = root / "bin/uwsm-app"
            launcher.write_text(
                f"#!{shutil.which('sh')}\n"
                'if [ ! -f "$XDG_STATE_HOME/attempts" ]; then\n'
                '  printf "failed\\n" > "$XDG_STATE_HOME/attempts"\n'
                '  printf "fixture launch rejected" >&2; exit 17\n'
                'fi\nprintf "completed\\n" >> "$XDG_STATE_HOME/attempts"\n'
                'printf "%s\\n" "$@" > "$XDG_STATE_HOME/launch-arguments"\n'
            )
            launcher.chmod(0o700)
            (root / "data/applications/journey.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Journey\nExec=true\n"
            )
            (root / "data/applications/unrelated.desktop").write_text(
                "[Desktop Entry]\nType=Application\nName=Unrelated\nExec=true\n"
            )
            config = root / "bus.conf"
            config.write_text(
                f'<busconfig><type>session</type><listen>unix:tmpdir={root / "run"}</listen>'
                '<auth>EXTERNAL</auth><policy context="default"><allow user="*"/>'
                '<allow own="*"/><allow send_destination="*"/><allow receive_sender="*"/>'
                '</policy></busconfig>'
            )
            # Do not inherit host service/compositor addresses or XDG locations.
            environment = {key: os.environ[key] for key in (
                "FONTCONFIG_FILE", "QT_PLUGIN_PATH", "TZDIR", "LLVM_PROFILE_FILE"
            ) if key in os.environ}
            environment.update({"HOME": str(root), "PATH": str(root / "bin"),
                                "XDG_DATA_DIRS": str(root / "empty"), "RUST_LOG": "error",
                                "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                                "QML2_IMPORT_PATH": str(ROOT / "qml"), "TZ": "UTC",
                                "SHELLLIST_MODE": "floating"})
            environment["APP_DAEMON_UPDATE_WORKER"] = "/nonexistent/fixture-update-worker"
            # This journey owns standalone handoff; workspace coordination has
            # its own private multi-daemon acceptance test.
            environment["SHELLLIST_TEMPORARY_WORKSPACES"] = "0"
            # Scope the launch journal to this fixture; no host compositor
            # socket or environment is inherited.
            environment["HYPRLAND_INSTANCE_SIGNATURE"] = "fixture"
            for variable, name in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                                   ("XDG_STATE_HOME", "state"), ("XDG_CACHE_HOME", "cache"),
                                   ("XDG_RUNTIME_DIR", "run")):
                environment[variable] = str(root / name)
            children = []
            logs = []
            bus = None
            try:
                bus = subprocess.Popen([shutil.which("dbus-daemon"), f"--config-file={config}",
                                        "--nofork", "--print-address=1"],
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       start_new_session=True, env=environment)
                children.append(bus)
                with selectors.DefaultSelector() as selector:
                    selector.register(bus.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(10), "private bus failed to start")
                    address = bus.stdout.readline().decode().strip()
                self.assertTrue(address.startswith("unix:"), address)
                environment.update(DBUS_SESSION_BUS_ADDRESS=address, DBUS_SYSTEM_BUS_ADDRESS=address)
                daemon_log = (root / "daemon.log").open("w+")
                logs.append(daemon_log)
                daemon = subprocess.Popen([str(args.app_daemon.resolve()), "daemon"],
                                          env=environment, stdout=daemon_log, stderr=daemon_log,
                                          start_new_session=True)
                children.append(daemon)
                native_log = (root / "native.log").open("w+")
                logs.append(native_log)
                native = subprocess.Popen([shutil.which(args.quickshell), "--no-color", "--path",
                                           str(ROOT / "tests/e2e/application.qml")],
                                          env=environment, stdout=native_log, stderr=native_log,
                                          start_new_session=True)
                children.append(native)
                try:
                    native.wait(timeout=90)
                except subprocess.TimeoutExpired:
                    native_log.seek(0)
                    self.fail("Native journey timed out:\n" + native_log.read())
                native_log.seek(0)
                output = native_log.read()
                self.assertEqual(native.returncode, 0, output)
                self.assertIn("SHELLLIST_E2E_PASS application", output)
                self.assertNotIn("SHELLLIST_E2E_FAIL", output)
                self.assertEqual((root / "state/attempts").read_text().splitlines(), ["failed", "completed"])
                self.assertIn("journey.desktop", (root / "state/launch-arguments").read_text())
                # Verify persistence through the owner API after restart, never
                # open the live Turso file from a second database writer.
                daemon.terminate()
                daemon.wait(timeout=15)
                daemon = subprocess.Popen([str(args.app_daemon.resolve()), "daemon"],
                                          env=environment, stdout=daemon_log, stderr=daemon_log,
                                          start_new_session=True)
                children.append(daemon)
                deadline = time.monotonic() + 15
                restored = None
                while time.monotonic() < deadline and restored is None:
                    client = subprocess.Popen([str(args.app_daemon.resolve()), "client"], env=environment,
                                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    try:
                        client.stdin.write((json.dumps({"op": "call", "id": "verify-catalog", "method": "applications.catalog", "params": {}}) + "\n").encode())
                        client.stdin.flush()
                        with selectors.DefaultSelector() as selector:
                            selector.register(client.stdout, selectors.EVENT_READ)
                            if selector.select(2):
                                line = client.stdout.readline()
                                reply = json.loads(line) if line else {}
                                restored = reply.get("response", {}).get("data", {}).get("catalog")
                    finally:
                        client.kill()
                        client.wait(timeout=5)
                        client.stdin.close()
                        client.stdout.close()
                    if restored is None:
                        time.sleep(0.05)
                self.assertIsNotNone(restored, "catalog unavailable after restart")
                journey = next(row for row in restored["entries"] if row["id"] == "journey.desktop")
                self.assertEqual(journey["category"], "text")
                self.assertTrue((root / "state/app-daemon/software-catalog-turso-v1.db").is_file())
            finally:
                for child in reversed(children):
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    child.wait(timeout=10)
                for log in logs:
                    log.close()
                for stream in (getattr(bus, "stdout", None), getattr(bus, "stderr", None)):
                    if stream:
                        stream.close()


if __name__ == "__main__":
    unittest.main(argv=[__file__], verbosity=2)
