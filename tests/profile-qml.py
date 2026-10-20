#!/usr/bin/env python3
"""Collect bounded native execution observations, never inferred line/branch coverage."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
KINDS = {"Creating": "objects", "Binding": "bindings", "Javascript": "executables", "HandlingSignal": "executables"}
PROFILER_TIMEOUT = 180
NORMALIZE_TIMEOUT = 60
MAX_TRACE_BYTES = 512 * 1024 * 1024
MAX_EVENTS = 5_000_000
REPORTS = ("coverage.json", "runtime.json")


def source_snapshot(root):
    config = json.loads((root / "qmlqualitylens.config.json").read_text())
    sources, visited = {}, set()
    for source_root in config["source_roots"]:
        for directory, dirs, files in os.walk(root / source_root, followlinks=True):
            real = Path(directory).resolve()
            if real in visited or not real.is_relative_to(root):
                dirs[:] = []
                continue
            visited.add(real)
            dirs[:] = [name for name in dirs if name not in {"target", "node_modules", ".git", ".direnv", "__pycache__"}]
            for name in files:
                path = Path(directory) / name
                if path.suffix not in {".qml", ".js"}:
                    continue
                sources[str(path.resolve())] = {
                    "file": str(path.relative_to(root)),
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
    return sources


def observation_definition(element, sources):
    metadata = {child.tag: child.text for child in element}
    kind = metadata.get("type")
    # Compiling and module %entry events do not establish function execution.
    if kind not in KINDS or metadata.get("details") == "%entry":
        return None
    filename = urlparse(metadata.get("filename") or "")
    if filename.scheme != "file":
        return None
    source = sources.get(str(Path(unquote(filename.path)).resolve()))
    line = int(metadata.get("line") or 0)
    return (source, kind, line) if source and line > 0 else None


def normalize(trace, sources, environment, emit_event=None):
    if trace.stat().st_size > MAX_TRACE_BYTES:
        raise ValueError("Qt trace exceeds the size limit; no partial evidence was published")
    deadline = time.monotonic() + NORMALIZE_TIMEOUT
    definitions, observed, events, stack = {}, {}, [], []
    ignored = count = ranges = 0
    for action, element in ET.iterparse(trace, events=["start", "end"]):
        if action == "start":
            stack.append(element)
            continue
        if time.monotonic() > deadline:
            raise ValueError("Qt trace normalization timed out; no partial evidence was published")
        if element.tag == "event":
            # Resolve source URLs once per definition, not millions of ranges.
            definitions[element.get("index")] = observation_definition(element, sources)
        elif element.tag == "range":
            ranges += 1
            if ranges > MAX_EVENTS:
                raise ValueError("Qt trace normalization limit exceeded; no partial evidence was published")
            definition = definitions.get(element.get("eventIndex"))
            if definition:
                source, kind, line = definition
                record = observed.get(source["file"])
                if record is None:
                    record = {**source, **{key: set() for key in KINDS.values()}}
                    observed[source["file"]] = record
                record[KINDS[kind]].add(line)
                duration = element.get("duration")
                if duration is not None:
                    nanoseconds = int(duration)
                    if nanoseconds < 0:
                        raise ValueError("Qt trace contains a negative duration")
                    event = {"category": kind, "duration_ms": nanoseconds / 1_000_000,
                             "file": source["file"], "line": line}
                    (emit_event or events.append)(event)
                    count += 1
            else:
                ignored += 1
        if element.tag in {"event", "range"}:
            # clear() alone leaves millions of empty child nodes on the parent.
            if len(stack) > 1:
                stack[-2].remove(element)
            element.clear()
        stack.pop()
    if not observed or not count:
        raise ValueError("Qt trace has no mapped project execution observations")
    files = [{**entry, **{key: sorted(entry[key]) for key in set(KINDS.values())}} for entry in observed.values()]
    coverage = {"format": "qml-profiler-observations", "environment": environment, "files": files}
    performance = {"scenario": "qml-tests", "environment": environment,
                   "ignored_framework_or_nonexecution_events": ignored, "observed_event_count": count}
    if emit_event is None:
        performance["events"] = events
    return coverage, performance


def stop_process_group(process):
    def send(sig):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass
    send(signal.SIGTERM)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    finally:
        # Also retire descendants that survived their parent or ignored TERM.
        send(signal.SIGKILL)
        process.wait()


def run_profiler(command, environment=None, timeout=PROFILER_TIMEOUT):
    process = subprocess.Popen(command, cwd=ROOT, env=environment, start_new_session=True)
    try:
        return process.wait(timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("QML profiling timed out; no execution evidence was published") from error
    finally:
        # The adapter's signal handler unwinds here on an outer Lens timeout too.
        stop_process_group(process)


def interrupted(signum, _frame):
    raise RuntimeError(f"QML profiling interrupted by signal {signum}")


def publish(trace, sources, environment, output):
    # Stream duration records to disk rather than retaining a second huge trace.
    # Final paths are replaced only after successful parsing and source checking.
    with tempfile.TemporaryDirectory(prefix=".profile-", dir=output) as directory:
        staging = Path(directory)
        with (staging / "runtime.json").open("w") as runtime:
            runtime.write('{"events":[')
            first = True

            def emit(event):
                nonlocal first
                if not first:
                    runtime.write(",")
                runtime.write(json.dumps(event, separators=(",", ":")))
                first = False

            coverage, performance = normalize(trace, sources, environment, emit)
            runtime.write("]," + json.dumps(performance, separators=(",", ":"))[1:] + "\n")
        (staging / "coverage.json").write_text(json.dumps(coverage, separators=(",", ":")) + "\n")
        if sources != source_snapshot(ROOT):
            raise RuntimeError("Sources changed during profiling; refusing stale observations")
        for name in REPORTS:
            (staging / name).replace(output / name)
    return len(coverage["files"]), performance["observed_event_count"]


def main(arguments):
    if arguments == ["--version"]:
        print("profile-qml 2; " + subprocess.check_output(["qmllint", "--version"], text=True, timeout=5).strip())
        return 0
    output = ROOT / "target/profiling"
    output.mkdir(parents=True, exist_ok=True)
    trace = output / "tests.qtd"
    for name in (*REPORTS, "tests.qtd"):
        (output / name).unlink(missing_ok=True)
    before = source_snapshot(ROOT)
    environment = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       QML_XHR_ALLOW_FILE_READ="1", TZ="UTC")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    # Qt 6.11 misattributes standalone JS functions across test-suite engines.
    # Scenegraph events aren't frame measurements here and are not collected.
    command = ["qmlprofiler", "--port", str(port), "--include", "binding,creating,handlingsignal",
               "--output", str(trace), str(ROOT / "tests/run-qmlquality-tests.sh"), *arguments]
    try:
        result = run_profiler(command, environment)
        if result:
            return result
        version = subprocess.check_output(["qmllint", "--version"], text=True, timeout=5)
        qt = re.search(r"\d+\.\d+\.\d+", version)
        if not qt:
            raise RuntimeError("Cannot determine Qt version")
        with trace.open("rb") as stream:
            trace_hash = hashlib.file_digest(stream, "sha256").hexdigest()
        provenance = {"qt": qt.group(), "platform": environment["QT_QPA_PLATFORM"],
                      "renderer": environment["QT_QUICK_BACKEND"], "source_format": "qt-qtd-nanoseconds",
                      "frames_measured": False,
                      "scope": "QML test-suite bindings, creation and signal handlers; includes setup/teardown and profiler overhead",
                      "omitted": "Standalone JavaScript functions (unreliable multi-engine attribution); display frame timing",
                      "trace_sha256": trace_hash,
                      "source_sha256": {entry["file"]: entry["sha256"] for entry in before.values()}}
        files, events = publish(trace, before, provenance, output)
        print(f"Qt profiler: {files} observed project files; {events} duration events", file=sys.stderr)
        return 0
    except BaseException:
        for name in REPORTS:
            (output / name).unlink(missing_ok=True)
        raise


if __name__ == "__main__":
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, interrupted)
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, ET.ParseError) as error:
        print(f"QML profiling failed: {error}", file=sys.stderr)
        sys.exit(1)
