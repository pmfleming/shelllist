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

    def test_rejects_schema_default_and_missing_metadata(self):
        for key, value in [("schema_version", 2), ("schema_version", True),
                           ("default_surface", "absent"), ("default_surface", []),
                           ("surfaces", []), ("surfaces", {})]:
            with self.subTest(key=key, value=value):
                catalog = dict(self.catalog, **{key: value})
                with self.assertRaises(ValueError):
                    generator.render(catalog)
        with self.assertRaises(ValueError):
            generator.render(dict(self.catalog, unexpected=True))
        for key in generator.SURFACE_KEYS:
            catalog = copy.deepcopy(self.catalog)
            del catalog["surfaces"][0][key]
            with self.subTest(missing=key), self.assertRaises(ValueError):
                generator.render(catalog)

    def test_ids_cannot_be_duplicate_shadow_commands_or_inject_shell(self):
        invalid = ["wifi", "WiFi", "new_panel", "a|b", "x;true", "$(touch foo)", "", None]
        for ident in invalid + sorted(generator.RESERVED_IDS):
            with self.subTest(ident=ident), self.assertRaises(ValueError):
                catalog = copy.deepcopy(self.catalog)
                catalog["surfaces"][0]["id"] = ident
                generator.render(catalog)

    def test_invalid_loading_resident_state_and_labels_fail_closed(self):
        for key, value in [("loading", "preload"), ("loading", True),
                           ("resident_state", "unknown-worker"), ("name", ""),
                           ("name", "bad\nlabel"), ("icon", None)]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                catalog = copy.deepcopy(self.catalog)
                catalog["surfaces"][0][key] = value
                generator.render(catalog)

    def test_shortcut_conflicts_and_malformed_defaults_fail(self):
        for key, value in [("option", "mediaShortcut"), ("option", "updateLogsShortcut"),
                           ("option", "bad-name"), ("default", "SUPER SHIFT, M"),
                           ("default", "SUPER SHIFT, U"), ("default", "no comma"),
                           ("default", "SUPER, A, exec, something"), ("description", "")]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                catalog = copy.deepcopy(self.catalog)
                catalog["surfaces"][7]["home_manager_shortcut"][key] = value
                generator.render(catalog)

    def test_metadata_change_and_new_surface_change_generated_output(self):
        before = generator.render(self.catalog)
        self.catalog["surfaces"][0]["name"] = 'Apps "quoted"'
        added = copy.deepcopy(self.catalog["surfaces"][0])
        added.update(id="example-panel", name="Example", loading="eager")
        self.catalog["surfaces"].append(added)
        after = generator.render(self.catalog)
        self.assertNotEqual(before, after)
        self.assertIn('Toggle Shelllist Apps \\"quoted\\"', after)
        self.assertIn('"example-panel"', after)
        self.assertIn('"id": "example-panel"', after)
        # A Home Manager option can deliberately have no default binding.
        self.catalog["surfaces"][7]["home_manager_shortcut"]["default"] = None
        generator.validate(self.catalog)

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
