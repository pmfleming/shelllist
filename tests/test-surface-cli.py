#!/usr/bin/env python3
"""Exercise the packaged CLI; replace all desktop/clipboard entry points with fakes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

def record(program, args):
    with open(os.environ["CATALOG_TEST_LOG"], "a") as log:
        log.write(json.dumps({"program": program, "args": args,
                              "initial": os.environ.get("SHELLLIST_INITIAL_SURFACE"),
                              "mode": os.environ.get("SHELLLIST_MODE")}) + "\n")

def mock_quickshell(args):
    record("quickshell", args)
    if args == ["list", "--all"]:
        if os.environ.get("CATALOG_TEST_RUNNING", "1") == "1":
            print("  Config path: " + os.environ["CATALOG_TEST_CONFIG"] + "/shell.qml")
    elif args[0] == "ipc":
        action = args[args.index("shelllist") + 1]
        if action == "listSurfaces":
            catalog = json.loads(Path(os.environ["CATALOG_TEST_SOURCE"]).read_text())
            print(json.dumps([{key: surface[key] for key in ("id", "name", "icon")} for surface in catalog["surfaces"]]))
        else:
            print("ok" if action == "ping" else os.environ.get("CATALOG_TEST_REPLY", "ok"))
    elif args[0] != "--path":
        raise RuntimeError("unexpected mock invocation: " + repr(args))

def mock_clipboard():
    for line in sys.stdin:
        request = json.loads(line)
        record("clip-daemon", request)
        print(json.dumps({"kind": "response", "id": request["id"], "ok": True, "response": {"ok": True}}), flush=True)
        if request["op"] == "shutdown":
            return

if len(sys.argv) > 1 and sys.argv[1] == "--mock-quickshell":
    mock_quickshell(sys.argv[2:])
    sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == "--mock-clipboard":
    mock_clipboard()
    sys.exit(0)

CLI = Path(sys.argv[1])
SOURCE = Path(sys.argv[2])
CATALOG = json.loads(SOURCE.read_text())

class SurfaceCliTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.log = self.root / "calls.jsonl"
        environment = self.root / "environment.bash"
        environment.write_text('''
quickshell() {
  CATALOG_TEST_CONFIG="$config_path" "$CATALOG_TEST_PYTHON" "$CATALOG_TEST_MOCK" --mock-quickshell "$@"
}
function clip-daemon() {
  "$CATALOG_TEST_PYTHON" "$CATALOG_TEST_MOCK" --mock-clipboard
}
# Bash's exec bypasses functions, so intercept it too. Never launch a real host.
exec() {
  if [ "$1" != quickshell ]; then echo "Unexpected exec: $*" >&2; exit 99; fi
  shift
  quickshell "$@"
  exit $?
}
''')
        self.env = dict(os.environ, BASH_ENV=str(environment),
                        CATALOG_TEST_LOG=str(self.log), CATALOG_TEST_SOURCE=str(SOURCE),
                        CATALOG_TEST_PYTHON=sys.executable, CATALOG_TEST_MOCK=str(Path(__file__).resolve()),
                        CATALOG_TEST_RUNNING="1", CATALOG_TEST_REPLY="ok")
        self.env.pop("SHELLLIST_INITIAL_SURFACE", None)
        self.env.pop("SHELLLIST_MODE", None)

    def run_cli(self, args, expected=0):
        self.log.write_text("")
        result = subprocess.run([str(CLI), *args], env=self.env, text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, expected, (args, result.stdout, result.stderr))
        self.calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return result

    def test_all_surface_forms_route_exact_ids_and_actions(self):
        for surface in CATALOG["surfaces"]:
            ident = surface["id"]
            for args, action in [([ident], "toggle"), ([ident, "open"], "open"),
                                 ([ident, "toggle"], "toggle"), (["open", ident], "open"),
                                 (["toggle", ident], "toggle")]:
                with self.subTest(args=args):
                    self.run_cli(args)
                    self.assertEqual(self.calls[-1]["args"][-2:], [action, ident])
                    self.assertTrue(all(call["program"] == "quickshell" for call in self.calls))

    def test_legacy_activity_alias_only_opens_agenda(self):
        self.assertNotIn("activity", [entry["id"] for entry in CATALOG["surfaces"]])
        for args, action in [(["activity"], "toggle"), (["activity", "open"], "open"),
                             (["open", "activity"], "open"), (["toggle", "activity"], "toggle")]:
            with self.subTest(args=args):
                self.run_cli(args)
                self.assertEqual(self.calls[-1]["args"][-2:], [action, "agenda"])
        self.env["CATALOG_TEST_RUNNING"] = "0"
        self.run_cli(["floating", "activity"])
        self.assertEqual(self.calls[-1]["initial"], "agenda")
        self.assertEqual(self.calls[-1]["mode"], "floating")

    def test_update_run_deep_link_is_data_not_a_command(self):
        self.run_cli(["updates", "run", "boot-123-run-456"])
        self.assertEqual(self.calls[-1]["args"][-2:], ["openUpdateRun", "boot-123-run-456"])
        for ident in ["../escape", "run;reboot", "-option", "", "x" * 161]:
            self.run_cli(["updates", "run", ident], expected=2)
            self.assertEqual(self.calls, [])

    def test_invalid_surfaces_and_arguments_do_not_dispatch(self):
        for args in [["unknown"], ["open", "wifi;quit"], ["toggle", "WiFi"],
                     ["floating", "unknown"], ["audio", "bad-action"],
                     ["open", "wifi", "extra"], ["clipboard", "kept", "bad"]]:
            with self.subTest(args=args):
                self.run_cli(args, expected=2)
                self.assertEqual(self.calls, [])
        self.env["CATALOG_TEST_REPLY"] = "rejected"
        self.run_cli(["open", "wifi"], expected=1)
        self.assertEqual(self.calls[-1]["args"][-2:], ["open", "wifi"])

if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
