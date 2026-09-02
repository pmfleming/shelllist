#!/usr/bin/env python3
"""Measure Shelllist command acknowledgement and target-session frame latency."""

import argparse
import json
import statistics
import subprocess
import time


def shelllist(*arguments: str) -> str:
    return subprocess.check_output(["shelllist", *arguments], text=True).strip()


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, int(len(ordered) * fraction))
    return ordered[index]


def wait_for_frame(surface: str, previous_request: float, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    latest = {}
    while time.monotonic() < deadline:
        latest = json.loads(shelllist("responsiveness"))
        requested = float(latest.get("open_requested_at_ms", 0))
        framed = float(latest.get("first_frame_at_ms", 0))
        content = latest.get("content", {})
        if (requested > previous_request and framed >= requested
                and content.get("surface") == surface):
            return latest
        time.sleep(0.01)
    raise TimeoutError(f"no completed frame/content timing for {surface}: {latest}")


def sample(surface: str, phase: str, timeout: float) -> dict:
    before = json.loads(shelllist("responsiveness"))
    started = time.perf_counter()
    shelllist("open", surface)
    acknowledged_ms = (time.perf_counter() - started) * 1000
    trace = wait_for_frame(surface, float(before.get("open_requested_at_ms", 0)), timeout)
    result = {
        "surface": surface,
        "phase": phase,
        "command_ack_ms": acknowledged_ms,
        "open_to_first_frame_ms": float(trace["open_to_first_frame_ms"]),
        "content_ready_ms": float(trace["content"]["latency_ms"]),
        "search_rank_ms": float(trace.get("search_rank_ms", -1)),
        "catalog_to_model_ms": float(trace.get("catalog_to_model_ms", -1)),
    }
    shelllist("hide")
    time.sleep(0.15)
    return result


def summary(samples: list[dict], field: str) -> dict:
    values = [sample[field] for sample in samples if sample[field] >= 0]
    if not values:
        return {"median": -1, "p95": -1, "maximum": -1}
    return {
        "median": statistics.median(values),
        "p95": percentile(values, 0.95),
        "maximum": max(values),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--surfaces", nargs="+", default=[
        "applications", "wifi", "bluetooth", "clipboard", "battery", "activity"
    ])
    parser.add_argument("--timeout", type=float, default=3.0)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--max-command-ack-ms", type=float, default=50.0)
    parser.add_argument("--max-warm-first-frame-ms", type=float, default=100.0)
    parser.add_argument("--max-cold-content-ms", type=float, default=300.0)
    args = parser.parse_args()

    shelllist("daemon")
    shelllist("hide")
    status = json.loads(shelllist("status"))
    already_opened = status.get("opened", {})
    samples = []
    try:
        for surface in args.surfaces:
            phase = "warm-cache" if already_opened.get(surface) else "cold"
            samples.append(sample(surface, phase, args.timeout))
        for surface in args.surfaces:
            samples.append(sample(surface, "warm", args.timeout))
    finally:
        shelllist("hide")

    warm = [value for value in samples if value["phase"] == "warm"]
    report = {
        "schema_version": 1,
        "scenario": "target-session-surface-responsiveness",
        "samples": samples,
        "summary": {
            "command_ack_ms": summary(samples, "command_ack_ms"),
            "warm_open_to_first_frame_ms": summary(warm, "open_to_first_frame_ms"),
            "cold_content_ready_ms": summary(
                [value for value in samples if value["phase"] == "cold"],
                "content_ready_ms",
            ),
        },
        "budgets": {
            "max_command_ack_ms": args.max_command_ack_ms,
            "max_warm_first_frame_ms": args.max_warm_first_frame_ms,
            "max_cold_content_ms": args.max_cold_content_ms,
        },
    }
    print(json.dumps(report, indent=2))

    if not args.check:
        return 0
    failures = []
    if report["summary"]["command_ack_ms"]["p95"] > args.max_command_ack_ms:
        failures.append("command acknowledgement exceeds budget")
    if report["summary"]["warm_open_to_first_frame_ms"]["p95"] \
            > args.max_warm_first_frame_ms:
        failures.append("warm first frame exceeds budget")
    cold_content = report["summary"]["cold_content_ready_ms"]["p95"]
    if cold_content >= 0 and cold_content > args.max_cold_content_ms:
        failures.append("cold content readiness exceeds budget")
    if failures:
        raise SystemExit("; ".join(failures))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
