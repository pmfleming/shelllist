#!/usr/bin/env python3
"""Measure the already-running resident Shelllist host without changing UI state."""

import argparse
import json
import os
import subprocess
import time
from pathlib import Path


def command(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode()
    except (FileNotFoundError, PermissionError, UnicodeDecodeError):
        return ""


def find_process(predicate) -> int | None:
    for entry in os.listdir("/proc"):
        if entry.isdigit() and predicate(command(int(entry))):
            return int(entry)
    return None


def process_sample(pid: int) -> dict:
    fields = Path(f"/proc/{pid}/stat").read_text().split()
    status = {}
    for line in Path(f"/proc/{pid}/status").read_text().splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            status[key] = value.strip()
    return {
        "ticks": int(fields[13]) + int(fields[14]),
        "minor_faults": int(fields[9]),
        "major_faults": int(fields[11]),
        "rss_kib": int(status["VmRSS"].split()[0]),
        "threads": int(status["Threads"]),
    }


def pss_kib(pid: int) -> int:
    for line in Path(f"/proc/{pid}/smaps_rollup").read_text().splitlines():
        if line.startswith("Pss:"):
            return int(line.split()[1])
    return 0


def bridge_threads(host_pid: int) -> list[dict]:
    control_group = subprocess.check_output(
        ["systemctl", "--user", "show", "shelllist.service", "-p", "ControlGroup", "--value"],
        text=True,
    ).strip()
    pids = Path("/sys/fs/cgroup", control_group.lstrip("/"), "cgroup.procs").read_text().split()
    bridges = []
    for value in pids:
        pid = int(value)
        process_command = command(pid)
        if pid != host_pid and process_command.rstrip().endswith(" client"):
            bridges.append({
                "pid": pid,
                "command": Path(process_command.split()[0]).name,
                "threads": process_sample(pid)["threads"],
            })
    return bridges


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", type=float, default=20.0)
    parser.add_argument("--check", action="store_true", help="enforce the supplied budgets")
    parser.add_argument("--max-cpu-percent", type=float, default=2.0)
    parser.add_argument("--max-pss-mib", type=float, default=300.0)
    parser.add_argument("--max-bridge-threads", type=int, default=6)
    args = parser.parse_args()

    status = json.loads(subprocess.check_output(["shelllist", "status"], text=True))
    if status.get("visible"):
        raise SystemExit("refusing to benchmark while a Shelllist surface is visible")

    host_pid = find_process(lambda value: value.startswith("quickshell ") and "shelllist" in value)
    if host_pid is None:
        raise SystemExit("the resident Shelllist Quickshell process is not running")

    before = process_sample(host_pid)
    started = time.monotonic()
    time.sleep(args.duration)
    elapsed = time.monotonic() - started
    after = process_sample(host_pid)
    ticks_per_second = os.sysconf("SC_CLK_TCK")
    cpu_percent = (after["ticks"] - before["ticks"]) / ticks_per_second / elapsed * 100
    bridges = bridge_threads(host_pid)
    report = {
        "schema_version": 1,
        "scenario": "resident-hidden-warm",
        "duration_seconds": elapsed,
        "host": {
            "pid": host_pid,
            "cpu_percent_of_one_core": cpu_percent,
            "rss_mib": after["rss_kib"] / 1024,
            "pss_mib": pss_kib(host_pid) / 1024,
            "threads": after["threads"],
            "minor_faults_per_second": (after["minor_faults"] - before["minor_faults"]) / elapsed,
            "major_faults": after["major_faults"] - before["major_faults"],
        },
        "bridges": bridges,
        "budgets": {
            "max_cpu_percent": args.max_cpu_percent,
            "max_pss_mib": args.max_pss_mib,
            "max_bridge_threads": args.max_bridge_threads,
        },
    }
    print(json.dumps(report, indent=2))

    failures = []
    if cpu_percent > args.max_cpu_percent:
        failures.append(f"host CPU {cpu_percent:.2f}% exceeds {args.max_cpu_percent:.2f}%")
    if report["host"]["pss_mib"] > args.max_pss_mib:
        failures.append(f"host PSS {report['host']['pss_mib']:.1f} MiB exceeds {args.max_pss_mib:.1f} MiB")
    for bridge in bridges:
        if bridge["threads"] > args.max_bridge_threads:
            failures.append(
                f"{bridge['command']} uses {bridge['threads']} threads; budget is {args.max_bridge_threads}"
            )
    if args.check and failures:
        for failure in failures:
            print(f"performance budget failed: {failure}", file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
