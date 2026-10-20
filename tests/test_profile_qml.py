import importlib.util
from pathlib import Path
import tempfile
import unittest
import sys
import json
import os
import signal
import subprocess
import time
from unittest import mock

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

    def trace(self, directory, ranges=1):
        source = Path(directory) / "Source.qml"
        source.write_text("Item {}\n")
        trace = Path(directory) / "trace.qtd"
        trace.write_text('<trace><eventData><event index="1"><type>Binding</type>'
                         f'<filename>{source.as_uri()}</filename><line>1</line></event></eventData>'
                         '<profilerDataModel>' + '<range eventIndex="1" duration="2000000"/>' * ranges
                         + '</profilerDataModel></trace>')
        return trace, {str(source): {"file": "Source.qml", "sha256": "test"}}

    def test_repeated_ranges_resolve_definition_once_and_stream_without_loss(self):
        with tempfile.TemporaryDirectory() as directory:
            trace, sources = self.trace(directory, 10000)
            emitted = []
            original = Path.resolve
            with mock.patch.object(Path, "resolve", autospec=True, side_effect=original) as resolve:
                coverage, runtime = profiler.normalize(trace, sources, {}, emitted.append)
            self.assertEqual(resolve.call_count, 1)
            self.assertEqual(coverage["files"][0]["bindings"], [1])
            self.assertNotIn("events", runtime)
            self.assertEqual(runtime["observed_event_count"], len(emitted))
            self.assertEqual(sum(event["duration_ms"] for event in emitted), 20000)

    def test_limits_fail_instead_of_publishing_a_sample(self):
        with tempfile.TemporaryDirectory() as directory:
            trace, sources = self.trace(directory, 3)
            for name, value in [("MAX_TRACE_BYTES", 1), ("MAX_EVENTS", 2), ("NORMALIZE_TIMEOUT", -1)]:
                with self.subTest(limit=name), mock.patch.object(profiler, name, value):
                    with self.assertRaises(ValueError):
                        profiler.normalize(trace, sources, {})

    def test_publication_is_streamed_and_rejects_changed_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            trace, sources = self.trace(directory, 3)
            with mock.patch.object(profiler, "source_snapshot", return_value={}):
                with self.assertRaisesRegex(RuntimeError, "Sources changed"):
                    profiler.publish(trace, sources, {}, output)
            self.assertFalse((output / "runtime.json").exists())
            self.assertFalse((output / "coverage.json").exists())
            with mock.patch.object(profiler, "source_snapshot", return_value=sources):
                self.assertEqual(profiler.publish(trace, sources, {}, output), (1, 3))
            runtime = json.loads((output / "runtime.json").read_text())
            self.assertEqual(len(runtime["events"]), 3)
            self.assertEqual(runtime["observed_event_count"], 3)
            self.assertEqual(list(output.glob(".profile-*")), [])

    def test_failed_runner_removes_old_reports_and_sets_fixture_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "target/profiling"
            output.mkdir(parents=True)
            for name in profiler.REPORTS:
                (output / name).write_text("old evidence")
            with mock.patch.object(profiler, "ROOT", root), mock.patch.object(profiler, "source_snapshot", return_value={}), \
                    mock.patch.object(profiler, "run_profiler", return_value=1) as run:
                self.assertEqual(profiler.main([]), 1)
            env = run.call_args.args[1]
            self.assertEqual(env["QML_XHR_ALLOW_FILE_READ"], "1")
            self.assertEqual(env["QT_QPA_PLATFORM"], "offscreen")
            self.assertFalse(any((output / name).exists() for name in profiler.REPORTS))

    def test_truncated_trace_leaves_no_partial_report(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            trace, sources = self.trace(directory)
            trace.write_text(trace.read_text()[:-8])
            with self.assertRaises(profiler.ET.ParseError):
                profiler.publish(trace, sources, {}, output)
            self.assertFalse(any((output / name).exists() for name in profiler.REPORTS))
            self.assertEqual(list(output.glob(".profile-*")), [])

    def test_timeout_and_outer_signal_retire_descendants(self):
        for interrupt in [False, True]:
            with self.subTest(interrupt=interrupt), tempfile.TemporaryDirectory() as directory:
                marker = Path(directory) / "child.pid"
                child = ("import os,signal,time; from pathlib import Path; "
                         "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
                         f"Path({str(marker)!r}).write_text(str(os.getpid())); time.sleep(60)")
                parent = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(60)"
                driver = (f"import runpy,signal; m=runpy.run_path({profiler.__file__!r}); "
                          "signal.signal(signal.SIGTERM,m['interrupted']); "
                          f"m['run_profiler']({[sys.executable, '-c', parent]!r}, timeout={60 if interrupt else 1})")
                process = subprocess.Popen([sys.executable, "-c", driver], stderr=subprocess.DEVNULL)
                try:
                    deadline = time.monotonic() + 5
                    while not marker.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(marker.exists())
                    if interrupt:
                        process.terminate()
                    self.assertNotEqual(process.wait(timeout=8), 0)
                    stat = Path("/proc") / marker.read_text() / "stat"
                    deadline = time.monotonic() + 2
                    while stat.exists() and stat.read_text().split()[2] != "Z" and time.monotonic() < deadline:
                        time.sleep(0.01)
                    self.assertTrue(not stat.exists() or stat.read_text().split()[2] == "Z", "descendant survived adapter exit")
                finally:
                    if process.poll() is None:
                        process.kill()
                    process.wait()
                    if marker.exists():
                        try:
                            os.kill(int(marker.read_text()), signal.SIGKILL)
                        except ProcessLookupError:
                            pass

    def test_no_execution_is_not_a_passing_report(self):
        with tempfile.TemporaryDirectory() as directory:
            trace = Path(directory) / "empty.qtd"
            trace.write_text("<trace/>")
            with self.assertRaises(ValueError):
                profiler.normalize(trace, {}, {})


if __name__ == "__main__":
    unittest.main()
