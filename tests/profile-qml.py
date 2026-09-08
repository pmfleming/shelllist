#!/usr/bin/env python3
"""Collect real Qt execution sites and durations, not inferred line/branch coverage."""
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
KINDS = {"Creating": "objects", "Binding": "bindings", "Javascript": "executables", "HandlingSignal": "executables"}


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


def normalize(trace, sources, environment):
    definitions, observed, events = {}, {}, []
    ignored = 0
    for _, element in ET.iterparse(trace, events=["end"]):
        if element.tag == "event":
            definitions[element.get("index")] = {child.tag: child.text for child in element}
            element.clear()
        elif element.tag == "range":
            metadata = definitions.get(element.get("eventIndex"), {})
            kind = metadata.get("type")
            filename = urlparse(metadata.get("filename") or "")
            source = sources.get(str(Path(unquote(filename.path)).resolve())) if filename.scheme == "file" else None
            # Compiling and script-module %entry events do not establish execution
            # of the objects/functions whose source happens to share their line.
            if source and kind in KINDS and metadata.get("details") != "%entry":
                line = int(metadata.get("line") or 0)
                if line > 0:
                    record = observed.setdefault(source["file"], {**source, **{key: set() for key in KINDS.values()}})
                    record[KINDS[kind]].add(line)
                    duration = element.get("duration")
                    if duration is not None:
                        milliseconds = int(duration) / 1_000_000  # Qt .qtd uses nanoseconds.
                        if milliseconds >= 0:
                            events.append({"category": kind, "duration_ms": milliseconds,
                                           "file": source["file"], "line": line})
            else:
                ignored += 1
            element.clear()
    if not observed or not events:
        raise ValueError("Qt trace has no mapped project execution observations")
    files = [{**entry, **{key: sorted(entry[key]) for key in set(KINDS.values())}} for entry in observed.values()]
    coverage = {"format": "qml-profiler-observations", "environment": environment, "files": files}
    performance = {"scenario": "qml-tests", "environment": environment, "events": events,
                   "ignored_framework_or_nonexecution_events": ignored}
    return coverage, performance


def run_profiler(command):
    process = subprocess.Popen(command, cwd=ROOT, start_new_session=True)
    try:
        return process.wait(timeout=90)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        raise RuntimeError("QML profiling timed out; no execution evidence was published")


def main(arguments):
    if arguments == ["--version"]:
        print("profile-qml 1; " + subprocess.check_output(["qmllint", "--version"], text=True).strip())
        return 0
    output = ROOT / "target/profiling"
    output.mkdir(parents=True, exist_ok=True)
    for name in ["coverage.json", "runtime.json", "tests.qtd"]:
        (output / name).unlink(missing_ok=True)
    before = source_snapshot(ROOT)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    # Qt 6.11's JavaScript profiler reused function identities across the QML
    # engines in this suite (e.g. attributing test waits to booleanValue).
    # Use QML binding/creation/signal events, whose source locations remain
    # reliable. Do not publish that misleading JavaScript attribution.
    command = ["qmlprofiler", "--port", str(port), "--include",
               "binding,creating,handlingsignal,scenegraph", "--output", str(output / "tests.qtd"),
               str(ROOT / "tests/run-qmlquality-tests.sh"), *arguments]
    result = run_profiler(command)
    if result:
        return result
    if before != source_snapshot(ROOT):
        raise RuntimeError("Sources changed during profiling; refusing stale observations")
    version = subprocess.check_output(["qmllint", "--version"], text=True)
    qt = re.search(r"\d+\.\d+\.\d+", version)
    if not qt:
        raise RuntimeError("Cannot determine Qt version")
    environment = {"qt": qt.group(), "platform": os.environ.get("QT_QPA_PLATFORM", "unknown"),
                   "source_format": "qt-qtd-nanoseconds", "frames_measured": False,
                   "scope": "QML test-suite bindings, creation and signal handlers; includes setup/teardown and profiler overhead",
                   "omitted": "Standalone JavaScript functions (unreliable multi-engine attribution); display frame timing",
                   "trace_sha256": hashlib.sha256((output / "tests.qtd").read_bytes()).hexdigest(),
                   "source_sha256": {entry["file"]: entry["sha256"] for entry in before.values()}}
    coverage, performance = normalize(output / "tests.qtd", before, environment)
    for name, value in [("coverage.json", coverage), ("runtime.json", performance)]:
        (output / name).write_text(json.dumps(value, separators=(",", ":")) + "\n")
    print(f"Qt profiler: {len(coverage['files'])} observed project files; {len(performance['events'])} duration events", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"QML profiling failed: {error}", file=sys.stderr)
        sys.exit(1)
