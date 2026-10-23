//! Explicit budget gates over the lens's validated evidence, not duplicate collectors.
use crate::{artifacts, report};
use anyhow::{Context, Result, ensure};
use clap::Args;
use serde_json::{Value, json};
use std::path::Path;

fn nonnegative(text: &str) -> std::result::Result<f64, String> {
    let value: f64 = text
        .parse()
        .map_err(|_| "expected a finite nonnegative budget")?;
    if value.is_finite() && value >= 0.0 {
        Ok(value)
    } else {
        Err("budget must be finite and nonnegative".into())
    }
}

#[derive(Args, Clone, Debug)]
pub struct Budgets {
    #[arg(long, default_value_t = 2.0, value_parser = nonnegative)]
    max_cpu_percent: f64,
    #[arg(long, default_value_t = 300.0, value_parser = nonnegative)]
    max_pss_mib: f64,
    #[arg(long, default_value_t = 6)]
    max_bridge_threads: u64,
    #[arg(long, default_value_t = 50.0, value_parser = nonnegative)]
    max_command_ack_ms: f64,
    #[arg(long, default_value_t = 100.0, value_parser = nonnegative)]
    max_warm_first_frame_ms: f64,
    #[arg(long, default_value_t = 300.0, value_parser = nonnegative)]
    max_cold_content_ms: f64,
}

fn gate(name: &str, measured: Option<f64>, limit: f64, failures: &mut Vec<String>) -> Value {
    if !limit.is_finite() || limit < 0.0 {
        failures.push(format!("invalid {name} budget"));
    }
    match measured {
        Some(value) if value.is_finite() && value >= 0.0 => {
            if value > limit {
                failures.push(format!("{name} {value:.2} exceeds {limit:.2}"));
            }
        }
        _ => failures.push(format!("{name} is unavailable; cannot certify budget")),
    }
    json!({"measured":measured,"limit":limit})
}
fn p95(mut values: Vec<f64>) -> Option<f64> {
    if values.is_empty() || values.iter().any(|v| !v.is_finite() || *v < 0.0) {
        return None;
    }
    values.sort_by(f64::total_cmp);
    Some(values[(values.len() * 95 / 100).min(values.len() - 1)])
}

pub fn check(path: &Path, budgets: &Budgets) -> Result<()> {
    let output = path.join("budgets.json");
    if output.exists() {
        std::fs::remove_file(&output)?;
    }
    let (manifest, samples, events) = artifacts::load(path)?;
    let result = evaluate(&manifest, &samples, &events, budgets)?;
    artifacts::atomic_json(&output, &result)?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    ensure!(
        result["passed"] == true,
        "performance budgets failed: {}",
        result["failures"]
    );
    Ok(())
}

fn evaluate(
    manifest: &crate::model::Manifest,
    samples: &[crate::model::Sample],
    events: &[crate::model::Event],
    budgets: &Budgets,
) -> Result<Value> {
    ensure!(
        manifest.status == "complete",
        "cannot certify an incomplete run"
    );
    let mut failures = vec![];
    let mut metrics = serde_json::Map::new();
    if manifest.scenario == "resident-hidden" {
        let summary = report::summarize(manifest, samples, events);
        let host = summary
            .resources
            .iter()
            .find(|r| r.label == "ui-host" && r.phase == "capture")
            .context("missing host capture")?;
        metrics.insert(
            "cpu_percent_of_one_core".into(),
            gate(
                "host CPU",
                host.cpu_percent_one_core,
                budgets.max_cpu_percent,
                &mut failures,
            ),
        );
        metrics.insert(
            "pss_mib".into(),
            gate(
                "host PSS",
                host.pss_sampled_peak_bytes.map(|n| n as f64 / 1048576.0),
                budgets.max_pss_mib,
                &mut failures,
            ),
        );
        // Identify actual client bridges, not every child (e.g. search) in the unit.
        let bridges = manifest.settings["bridge_labels"]
            .as_array()
            .context("missing bridge inventory")?;
        for label in bridges {
            let label = label.as_str().context("invalid bridge label")?;
            let values: Vec<_> = samples
                .iter()
                .filter(|s| s.label == label && s.phase == "capture")
                .map(|s| s.counters.get("threads").and_then(|v| v.value))
                .collect();
            let measured = if values.is_empty() || values.iter().any(Option::is_none) {
                None
            } else {
                values.into_iter().flatten().max().map(|n| n as f64)
            };
            metrics.insert(
                format!("{label} threads"),
                gate(
                    label,
                    measured,
                    budgets.max_bridge_threads as f64,
                    &mut failures,
                ),
            );
        }
    } else {
        ensure!(
            manifest.scenario == "warm-open",
            "budgets require resident-hidden or warm-open evidence"
        );
        let trials: Vec<_> = events
            .iter()
            .filter(|e| e.kind == "trial_finished" && e.data["status"] == "ok")
            .collect();
        let numbers = |phase: Option<&str>, field: &str| -> Option<f64> {
            p95(trials
                .iter()
                .filter(|e| phase.is_none_or(|p| e.phase == p))
                .map(|e| e.data[field].as_f64().unwrap_or(f64::NAN))
                .collect())
        };
        metrics.insert(
            "command_ack_ms_p95".into(),
            gate(
                "command acknowledgement",
                numbers(None, "ack_ms"),
                budgets.max_command_ack_ms,
                &mut failures,
            ),
        );
        metrics.insert(
            "warm_first_frame_ms_p95".into(),
            gate(
                "warm Qt frame callback",
                numbers(Some("warm-open"), "qt_frame_callback_ms"),
                budgets.max_warm_first_frame_ms,
                &mut failures,
            ),
        );
        let cold: Vec<_> = trials
            .iter()
            .filter(|e| e.data["content"]["warm"] == false)
            .map(|e| e.data["content"]["latency_ms"].as_f64().unwrap_or(f64::NAN))
            .collect();
        // A warm process cannot supply a cold observation. Say so, never invent one.
        metrics.insert(
            "cold_content_ms_p95".into(),
            if cold.is_empty() {
                json!({"not_measured":"content was already warm"})
            } else {
                gate(
                    "cold content readiness",
                    p95(cold),
                    budgets.max_cold_content_ms,
                    &mut failures,
                )
            },
        );
    }
    Ok(json!({"passed":failures.is_empty(),"metrics":metrics,"failures":failures}))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn limits() -> Budgets {
        Budgets {
            max_cpu_percent: 2.0,
            max_pss_mib: 300.0,
            max_bridge_threads: 6,
            max_command_ack_ms: 50.0,
            max_warm_first_frame_ms: 100.0,
            max_cold_content_ms: 300.0,
        }
    }
    fn manifest(scenario: &str) -> crate::model::Manifest {
        serde_json::from_value(json!({"schema_version":2,"run_id":"test","started_unix_ms":1,"finished_unix_ms":2,"status":"complete","error":null,"lens_version":"test","lens_sha256":"test","ticks_per_second":100,"targets":[],"cgroups":[],"scenario":scenario,"settings":{"bridge_labels":["ui-service-member:2"]},"context":{},"warnings":[],"hashes":{}})).unwrap()
    }
    #[test]
    fn resident_checks_host_peak_pss_and_each_bridge_without_counting_search() {
        use crate::model::{Counter, Metric, Sample};
        let host: Sample = serde_json::from_value(json!({"sequence":0,"elapsed_s":1.0,"phase":"capture","phase_sequence":1,"label":"ui-host","pid":1,"start_ticks":1,"interval_s":1.0,"counters":{},"rates":{},"gpu":[],"gpu_reason":null,"error":null,"collection_ms":0.0,"late_by_ms":0.0})).unwrap();
        let mut rows = vec![host];
        rows[0].counters.insert(
            "pss_bytes".into(),
            Counter::new(100 * 1048576, "bytes", "test"),
        );
        rows[0]
            .rates
            .insert("cpu_percent".into(), Metric::new(1.0, "percent", "test"));
        let mut bridge = rows[0].clone();
        bridge.label = "ui-service-member:2".into();
        bridge
            .counters
            .insert("threads".into(), Counter::new(6, "count", "test"));
        rows.push(bridge);
        let mut search = rows[1].clone();
        search.label = "ui-service-member:3".into();
        search.counters.get_mut("threads").unwrap().value = Some(100);
        rows.push(search);
        let m = manifest("resident-hidden");
        assert_eq!(evaluate(&m, &rows, &[], &limits()).unwrap()["passed"], true);
        rows[1].counters.get_mut("threads").unwrap().value = Some(7);
        assert_eq!(
            evaluate(&m, &rows, &[], &limits()).unwrap()["passed"],
            false
        );
        rows[1].counters.get_mut("threads").unwrap().value = None;
        assert_eq!(
            evaluate(&m, &rows, &[], &limits()).unwrap()["passed"],
            false
        );
        rows[0].counters.clear();
        assert_eq!(
            evaluate(&m, &rows, &[], &limits()).unwrap()["metrics"]["pss_mib"]["measured"],
            Value::Null
        );
    }
    #[test]
    fn responsiveness_checks_only_observed_cold_content_and_rejects_partial_runs() {
        let mut m = manifest("warm-open");
        let mut events = vec![crate::model::Event {
            elapsed_s: 1.0,
            trial: 1,
            phase: "warm-open".into(),
            kind: "trial_finished".into(),
            data: json!({"status":"ok","ack_ms":5.0,"qt_frame_callback_ms":20.0,"content":{"warm":true,"latency_ms":2000.0}}),
        }];
        let result = evaluate(&m, &[], &events, &limits()).unwrap();
        assert_eq!(result["passed"], true);
        assert!(result["metrics"]["cold_content_ms_p95"]["not_measured"].is_string());
        events[0].data["content"]["warm"] = json!(false);
        assert_eq!(
            evaluate(&m, &[], &events, &limits()).unwrap()["passed"],
            false
        );
        m.status = "partial".into();
        assert!(evaluate(&m, &[], &events, &limits()).is_err());
    }
    #[test]
    fn corrupt_artifacts_retire_old_budget_success() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("budgets.json"), r#"{"passed":true}"#).unwrap();
        assert!(check(dir.path(), &limits()).is_err());
        assert!(!dir.path().join("budgets.json").exists());
        for invalid in ["NaN", "inf", "-1"] {
            assert!(nonnegative(invalid).is_err());
        }
    }

    #[test]
    fn missing_and_negative_measurements_never_pass() {
        for value in [None, Some(-1.0), Some(f64::NAN), Some(51.0)] {
            let mut failures = vec![];
            gate("test", value, 50.0, &mut failures);
            assert!(!failures.is_empty());
        }
        let mut failures = vec![];
        gate("zero", Some(0.0), 50.0, &mut failures);
        assert!(failures.is_empty());
        assert_eq!(p95(vec![1.0, 2.0, 3.0]), Some(3.0));
        assert_eq!(p95(vec![]), None);
    }
}
