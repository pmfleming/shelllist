import importlib.util
from pathlib import Path
import tempfile
import unittest
import sys

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location("profile_qml", Path(__file__).with_name("profile-qml.py"))
profiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profiler)


class ProfilerNormalization(unittest.TestCase):
    def test_observations_preserve_categories_and_nanosecond_units(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "A space.qml"
            source.write_text("Item {}\n")
            trace = Path(directory) / "trace.qtd"
            events = "".join(
                f'<event index="{index}"><type>{kind}</type><filename>{source.as_uri()}</filename>'
                f'<line>{line}</line><details>{details}</details></event>'
                for index, kind, line, details in [(0, "Compiling", 1, ""), (1, "Javascript", 1, "%entry"),
                                                   (2, "Binding", 2, ""), (3, "Javascript", 4, "work")]
            )
            ranges = "".join(f'<range eventIndex="{index}" duration="2000000"/>' for index in range(4))
            trace.write_text(f'<trace><eventData>{events}</eventData><profilerDataModel>{ranges}</profilerDataModel></trace>')
            coverage, runtime = profiler.normalize(trace, {str(source): {"file": "A.qml", "sha256": "test"}},
                                                   {"qt": "6.11.1", "platform": "offscreen"})
            self.assertEqual(coverage["files"][0]["objects"], [])
            self.assertEqual(coverage["files"][0]["bindings"], [2])
            self.assertEqual(coverage["files"][0]["executables"], [4])
            self.assertEqual(len(runtime["events"]), 2)
            self.assertEqual(runtime["events"][0]["duration_ms"], 2)

    def test_no_execution_is_not_a_passing_report(self):
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / "empty.qtd"
            trace.write_text("<trace/>")
            with self.assertRaises(ValueError):
                profiler.normalize(trace, {}, {})


if __name__ == "__main__":
    unittest.main()
