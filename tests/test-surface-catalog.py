#!/usr/bin/env python3
"""Catalog schema and generator/freshness fault injection (no desktop effects)."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
GENERATOR = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools/generate-surface-catalog.py"
CATALOG = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "contracts/surface-catalog.json"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("surface_catalog", GENERATOR)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)

class SurfaceCatalogTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads(CATALOG.read_text())

    def test_ids_cannot_be_duplicate_shadow_commands_or_inject_shell(self):
        invalid = ["wifi", "WiFi", "new_panel", "a|b", "x;true", "$(touch foo)", "", None]
        for ident in invalid + sorted(generator.RESERVED_IDS):
            with self.subTest(ident=ident), self.assertRaises(ValueError):
                catalog = copy.deepcopy(self.catalog)
                catalog["surfaces"][0]["id"] = ident
                generator.render(catalog)

    def test_freshness_gate_catches_stale_missing_and_manually_edited_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "contracts").mkdir()
            (root / "shell").mkdir()
            source = root / "contracts/surface-catalog.json"
            source.write_text(json.dumps(self.catalog))
            command = [sys.executable, str(GENERATOR), "--root", str(root)]
            def check():
                return subprocess.run(command + ["--check"], capture_output=True).returncode
            self.assertNotEqual(check(), 0)
            subprocess.run(command, check=True)
            self.assertEqual(check(), 0)
            self.catalog["surfaces"][0]["icon"] = "changed"
            source.write_text(json.dumps(self.catalog))
            self.assertNotEqual(check(), 0)
            subprocess.run(command, check=True)
            self.assertEqual(check(), 0)
            output = root / "shell/SurfaceCatalog.generated.js"
            output.write_text(output.read_text() + "// hand edit\n")
            self.assertNotEqual(check(), 0)

if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
