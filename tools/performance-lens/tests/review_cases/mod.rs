use super::*;
use sha2::{Digest, Sha256};

fn write_json(path: &Path, value: &Value) {
    fs::write(path, serde_json::to_vec(value).unwrap()).unwrap();
}
fn compare(a: &Path, b: &Path, output: &Path, scopes: &[&str], succeeds: bool) -> Value {
    let mut cmd = Command::new(BIN);
    cmd.arg("compare")
        .arg("--baseline")
        .arg(a)
        .arg("--candidate")
        .arg(b)
        .arg("--output")
        .arg(output);
    for scope in scopes {
        cmd.arg("--changed-scope").arg(scope);
    }
    let result = cmd.output().unwrap();
    assert_eq!(
        result.status.success(),
        succeeds,
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    json(&output.join("comparison.json"))
}

#[test]
fn changed_scopes_preserve_all_other_comparison_guards() {
    let ui = Load::start();
    let daemon = Load::start();
    let root = tempfile::tempdir().unwrap();
    let extra = format!("bar={}", daemon.child.id());
    let a = capture_with(
        &ui,
        root.path(),
        "matched synthetic",
        "350ms",
        &["--related-pid", &extra],
    );
    let b = capture_with(
        &ui,
        root.path(),
        "matched synthetic",
        "350ms",
        &["--related-pid", &extra],
    );
    let unchanged = compare(&a, &b, &root.path().join("unchanged"), &[], true);
    assert!(
        unchanged["warnings"]
            .as_array()
            .unwrap()
            .iter()
            .any(|w| w.as_str().unwrap().contains("No deployed target"))
    );
    // Offline fixture changes stand in for rebuilt binaries; they are not measured speedups.
    let mut manifest = json(&b.join("manifest.json"));
    manifest["targets"]
        .as_array_mut()
        .unwrap()
        .iter_mut()
        .find(|t| t["label"] == "bar")
        .unwrap()["identity"]["executable_sha256"] = "rebuilt-daemon-fixture".into();
    write_json(&b.join("manifest.json"), &manifest);
    let rejected = compare(&a, &b, &root.path().join("unannounced"), &[], false);
    assert!(rejected["deltas"].is_null());
    let accepted = compare(&a, &b, &root.path().join("daemon"), &["bar"], true);
    assert_eq!(accepted["status"], "comparable_descriptive_only");
    for role in ["ui-host", "bar", "lens-observer"] {
        let row = accepted["deltas"]
            .as_array()
            .unwrap()
            .iter()
            .find(|r| r["metric"] == format!("{role} / capture / cpu_percent"))
            .unwrap();
        assert!(row["baseline_covered_s"].as_f64().unwrap() > 0.0);
        assert!(row["candidate"].is_number());
    }
    manifest["lens_sha256"] = "rebuilt-observer-fixture".into();
    manifest["targets"]
        .as_array_mut()
        .unwrap()
        .iter_mut()
        .find(|t| t["label"] == "lens-observer")
        .unwrap()["identity"]["executable_sha256"] = "rebuilt-observer-fixture".into();
    write_json(&b.join("manifest.json"), &manifest);
    compare(
        &a,
        &b,
        &root.path().join("observer-default"),
        &["bar"],
        false,
    );
    let allowed = ["bar", "lens-observer"];
    let conditional = compare(
        &a,
        &b,
        &root.path().join("observer-explicit"),
        &allowed,
        true,
    );
    assert_eq!(conditional["status"], "conditional_descriptive_only");
    assert_eq!(conditional["observer_changed"], true);
    assert!(conditional["warnings"].as_array().unwrap().iter().any(|w| {
        w.as_str()
            .unwrap()
            .contains("Collector equivalence is not verified")
    }));
    compare(
        &a,
        &b,
        &root.path().join("typo"),
        &["bar", "lens-observer", "*"],
        false,
    );

    for (case, pointer, value) in [
        (
            "workload",
            "/context/operator_conditions",
            Value::from("different workload"),
        ),
        ("protocol", "/settings/include_threads", Value::from(true)),
        ("incomplete", "/status", Value::from("partial")),
        ("config", "/settings/config_identity", Value::Null),
        ("clock", "/ticks_per_second", Value::from(1)),
        (
            "version",
            "/lens_version",
            Value::from("incompatible fixture"),
        ),
    ] {
        let mut changed = manifest.clone();
        *changed.pointer_mut(pointer).unwrap() = value;
        write_json(&b.join("manifest.json"), &changed);
        let report = compare(&a, &b, &root.path().join(case), &allowed, false);
        assert_eq!(report["status"], "incomparable");
        assert!(report["deltas"].is_null());
    }
    let mut changed = manifest;
    let mut extra = changed["targets"][0].clone();
    extra["label"] = "unexpected-member".into();
    extra["identity"]["pid"] = 1.into();
    changed["targets"].as_array_mut().unwrap().push(extra);
    write_json(&b.join("manifest.json"), &changed);
    compare(&a, &b, &root.path().join("membership"), &allowed, false);
}

#[test]
fn thread_capture_localizes_named_child_and_rejects_invalid_rehashed_intervals() {
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let run = capture_with(
        &load,
        root.path(),
        "synthetic task workload",
        "2600ms",
        &[
            "--include-threads",
            "--include-scheduler",
            "--detail-ms",
            "1000",
        ],
    );
    let summary = json(&run.join("summary.json"));
    for metric in [
        "rchar_per_second",
        "minor_faults_per_second",
        "observed_task_cpu_percent",
    ] {
        let rate = summary["rates"]
            .as_array()
            .unwrap()
            .iter()
            .find(|r| r["label"] == "ui-host" && r["phase"] == "capture" && r["metric"] == metric)
            .unwrap();
        assert!(rate["covered_s"].as_f64().unwrap() > 0.0);
        assert!(rate["average"].is_number());
        assert!(rate["valid_intervals"].as_u64().unwrap() > 0);
        assert!(rate["source"].is_string());
    }
    let hot = summary["threads"]
        .as_array()
        .unwrap()
        .iter()
        .find(|t| {
            t["label"] == "ui-host" && t["phase"] == "capture" && t["last_name"] == "perf-hot"
        })
        .unwrap();
    assert!(hot["cpu_percent_one_core"].as_f64().unwrap() > 0.0);
    assert!(hot["covered_s"].as_f64().unwrap() > 0.0);
    let report = Command::new(BIN)
        .args(["report", "--run"])
        .arg(&run)
        .output()
        .unwrap();
    assert!(
        report.status.success(),
        "{}",
        String::from_utf8_lossy(&report.stderr)
    );
    assert!(
        fs::read_to_string(run.join("report.html"))
            .unwrap()
            .contains("perf-hot")
    );
    assert_eq!(
        summary["rates"],
        json(&run.join("summary.json"))["rates"],
        "offline regeneration retains rate coverage"
    );
    let raw = fs::read_to_string(run.join("samples.jsonl")).unwrap();
    let mut rows: Vec<Value> = raw
        .lines()
        .map(|s| serde_json::from_str(s).unwrap())
        .collect();
    assert!(
        rows.iter().any(|s| s["gpu_reason"] == "not sampled at this cadence" && s.get("threads").is_some()),
        "opt-in task sampling must be independent of expensive detail cadence"
    );
    assert!(rows.iter().any(|s| {
        s["label"] == "ui-host"
            && s["rates"]["observed_task_cpu_percent"][1]
                .as_f64()
                .is_some_and(|v| v > 0.0)
    }));
    assert!(rows.iter().any(|s| {
        s["label"] == "ui-host"
            && s["rates"]["observed_task_voluntary_switches_per_second"][1]
                .as_f64()
                .is_some_and(|v| v > 0.0)
    }));
    // Every phase's first task observation is missing, not a zero CPU reading.
    let mut phases = std::collections::BTreeSet::new();
    for s in rows
        .iter()
        .filter(|s| s["label"] == "ui-host" && s.get("threads").is_some())
    {
        if phases.insert(s["phase_sequence"].as_u64().unwrap()) {
            for t in s["threads"]["tasks"].as_array().unwrap() {
                assert!(t["cpu_percent"][1].is_null());
            }
        }
    }
    let task = rows
        .iter_mut()
        .find_map(|s| {
            s.get_mut("threads")?
                .get_mut("tasks")?
                .as_array_mut()?
                .first_mut()
        })
        .unwrap();
    task["interval_s"] = 0.into();
    let bytes: Vec<u8> = rows
        .iter()
        .flat_map(|s| {
            let mut bytes = serde_json::to_vec(s).unwrap();
            bytes.push(b'\n');
            bytes
        })
        .collect();
    fs::write(run.join("samples.jsonl"), &bytes).unwrap();
    let mut manifest = json(&run.join("manifest.json"));
    manifest["hashes"]["samples.jsonl"] = format!("{:x}", Sha256::digest(&bytes)).into();
    write_json(&run.join("manifest.json"), &manifest);
    let result = Command::new(BIN)
        .args(["report", "--run"])
        .arg(&run)
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("invalid task interval"));
}

#[test]
fn task_churn_is_visible_between_expensive_detail_samples() {
    let load = Load::with_churn(true);
    let root = tempfile::tempdir().unwrap();
    let run = capture_with(
        &load,
        root.path(),
        "churning synthetic threads",
        "1000ms",
        &["--include-threads", "--detail-ms", "5000"],
    );
    let summary = json(&run.join("summary.json"));
    let tasks: Vec<_> = summary["threads"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|t| {
            t["label"] == "ui-host" && t["phase"] == "capture" && t["last_name"] == "perf-churn"
        })
        .collect();
    assert!(
        tasks.len() >= 2,
        "distinct task identities must remain separate"
    );
    assert!(
        tasks
            .iter()
            .filter(|t| t["cpu_percent_one_core"].as_f64().is_some_and(|v| v > 0.0))
            .count()
            >= 2
    );
    assert!(tasks.iter().all(|t| t["covered_s"].as_f64().unwrap() < 1.0));
    // Births sharing the previous snapshot's 10 ms tick are deliberately
    // ambiguous. Under scheduler alignment every birth can land in that tick.
    assert!(tasks.iter().all(|t| t["born_during_capture"].is_boolean()));
    let html = fs::read_to_string(run.join("report.html")).unwrap();
    assert!(html.contains("Unattributed thread CPU"));
    assert!(html.contains("Observed new threads by name"));
    assert_eq!(
        json(&run.join("manifest.json"))["settings"]["thread_cadence"],
        "base"
    );
}

#[test]
fn cgroup_capture_regenerates_and_rejects_rehashed_unknown_metric_descriptors() {
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let run = capture_with(
        &load,
        root.path(),
        "cgroup diagnostic",
        "400ms",
        &["--include-cgroups"],
    );
    let manifest = json(&run.join("manifest.json"));
    assert_eq!(manifest["settings"]["include_cgroups"], true);
    let groups = manifest["cgroups"].as_array().unwrap();
    let samples = fs::read_to_string(run.join("samples.jsonl")).unwrap();
    if groups.is_empty() {
        // Root-only or unavailable cgroup mounts are not fabricated as zero.
        assert!(
            manifest["warnings"]
                .as_array()
                .unwrap()
                .iter()
                .any(|w| w.as_str().unwrap().contains("cgroup unavailable"))
        );
    } else {
        let group = samples
            .lines()
            .map(|l| serde_json::from_str::<Value>(l).unwrap())
            .find(|s| s["cgroup"].is_string())
            .unwrap();
        assert_eq!(group["pid"], 0);
        assert!(group["counters"]["cpu_usage_usec"].is_array());
        assert!(group["counters"].get("rss_bytes").is_none());
        assert!(
            fs::read_to_string(run.join("report.html"))
                .unwrap()
                .contains("Cgroup v2 service accounting")
        );
    }
    let result = Command::new(BIN)
        .arg("report")
        .arg("--run")
        .arg(&run)
        .output()
        .unwrap();
    assert!(
        result.status.success(),
        "{}",
        String::from_utf8_lossy(&result.stderr)
    );
    let mut rows: Vec<Value> = samples
        .lines()
        .map(|line| serde_json::from_str(line).unwrap())
        .collect();
    rows[0]["counters"]["cpu_ticks"][0] = 99999.into();
    let bytes = rows
        .iter()
        .map(|row| format!("{row}\n"))
        .collect::<String>();
    fs::write(run.join("samples.jsonl"), &bytes).unwrap();
    let mut manifest = manifest;
    manifest["hashes"]["samples.jsonl"] = format!("{:x}", Sha256::digest(bytes.as_bytes())).into();
    write_json(&run.join("manifest.json"), &manifest);
    let result = Command::new(BIN)
        .arg("report")
        .arg("--run")
        .arg(&run)
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("unknown metric descriptor"));
}

#[test]
fn reserved_scope_labels_cannot_impersonate_the_observer() {
    for role in [
        "lens-observer",
        "cgroup:fixture",
        "ui-host",
        "related:bar-daemon:1",
        "ui-service-member:1",
    ] {
        let result = Command::new(BIN)
            .args([
                "capture",
                "--pid",
                &std::process::id().to_string(),
                "--related-pid",
                &format!("{role}=0"),
            ])
            .output()
            .unwrap();
        assert!(!result.status.success());
        assert!(String::from_utf8_lossy(&result.stderr).contains("reserved process label"));
    }
}
