use crate::{artifacts, comparison, model::*, report};
use serde_json::json;
use std::collections::BTreeMap;

fn target(label: &str, pid: u32) -> Target {
    Target {
        label: label.into(),
        identity: Identity {
            pid,
            start_ticks: 7,
            uid: 1,
            executable: "/fixture".into(),
            executable_sha256: "same".into(),
            boot_id: "boot".into(),
        },
    }
}
fn manifest() -> Manifest {
    Manifest {
        schema_version: SCHEMA,
        run_id: "fixture".into(),
        started_unix_ms: 0,
        finished_unix_ms: Some(1),
        status: "complete".into(),
        error: None,
        lens_version: "test".into(),
        lens_sha256: "lens".into(),
        ticks_per_second: 100,
        targets: vec![
            target("ui-host", 10),
            target("related:bar-daemon:20", 20),
            target("lens-observer", 30),
        ],
        scenario: "capture".into(),
        settings: json!({"config_identity":"fixture"}),
        context: BTreeMap::new(),
        warnings: vec![],
        hashes: BTreeMap::new(),
    }
}
fn summary(m: &Manifest, cpu: f64, seconds: f64) -> Summary {
    let mut s = report::summarize(m, &[], &[]);
    s.resources = m
        .targets
        .iter()
        .map(|t| ResourceSummary {
            label: t.label.clone(),
            phase: "capture".into(),
            samples: 3,
            cpu_percent_one_core: Some(cpu),
            valid_cpu_seconds: seconds,
            ..Default::default()
        })
        .collect();
    s
}

#[test]
fn daemon_roles_pair_across_pids_and_preserve_coverage_unknowns_and_provenance() {
    let a = manifest();
    let mut b = a.clone();
    b.targets[1].label = "related:bar-daemon:99".into();
    b.targets[1].identity.pid = 99;
    b.targets[1].identity.executable_sha256 = "new-daemon".into();
    let default_a = artifacts::comparison_context(&a, &[]);
    assert_ne!(default_a, artifacts::comparison_context(&b, &[]));
    let allowed = vec!["related:bar-daemon".into()];
    assert_eq!(
        artifacts::comparison_context(&a, &allowed),
        artifacts::comparison_context(&b, &allowed)
    );
    let result = comparison::scopes(&a, &b, &summary(&a, 80.0, 2.0), &summary(&b, 20.0, 3.0));
    assert!(result.unpaired.is_empty());
    let row = result
        .deltas
        .iter()
        .find(|r| r["metric"] == "related:bar-daemon / capture / cpu_percent")
        .unwrap();
    assert_eq!(row["absolute_delta"], -60.0);
    assert_eq!(row["relative_percent"], -75.0);
    assert_eq!(row["baseline_covered_s"], 2.0);
    assert_eq!(row["candidate_covered_s"], 3.0);
    assert!(result.deltas.iter().any(|r| r["scope"] == "lens-observer"));
    let missing = result
        .deltas
        .iter()
        .find(|r| r["metric"] == "related:bar-daemon / capture / pss_peak_bytes")
        .unwrap();
    assert!(missing["absolute_delta"].is_null());
    assert!(missing["unavailable_reason"].is_string());
    assert!(
        result
            .provenance
            .iter()
            .any(|p| p["scope"] == "related:bar-daemon" && p["executable_hashes_changed"] == true)
    );
    assert!(comparison::delta("zero", Some(0.0), Some(1.0))["relative_percent"].is_null());
}

#[test]
fn ambiguous_members_are_not_paired_by_pid_or_summed() {
    let mut a = manifest();
    a.targets.push(target("related:bar-daemon:21", 21));
    let mut b = a.clone();
    b.targets[1].label = "related:bar-daemon:100".into();
    b.targets[1].identity.pid = 100;
    let result = comparison::scopes(&a, &b, &summary(&a, 40.0, 2.0), &summary(&b, 20.0, 2.0));
    assert_eq!(result.unpaired.len(), 1);
    assert_eq!(result.unpaired[0]["scope"], "related:bar-daemon");
    assert_eq!(result.unpaired[0]["baseline_members"], 2);
    assert!(
        !result
            .deltas
            .iter()
            .any(|r| r["scope"] == "related:bar-daemon")
    );
    assert_eq!(artifacts::scope_role("worker:2"), "worker:2");
    assert_eq!(artifacts::scope_role("worker:3"), "worker:3");
}

#[test]
fn report_shows_unpaired_lifetime_counters_without_inventing_rates() {
    let mut m = manifest();
    m.settings["include_threads"] = true.into();
    let mut s = summary(&m, 97.0, 2.0);
    s.threads = vec![ThreadSummary {
        label: "ui-host".into(),
        phase: "capture".into(),
        tid: 7,
        start_ticks: 99,
        last_name: "<churning & task>".into(),
        observations: 1,
        max_observed_cpu_ticks: 80,
        covered_s: 0.0,
        cpu_percent_one_core: None,
    }];
    let root = tempfile::tempdir().unwrap();
    report::write(root.path(), &m, &s, &[], &[]).unwrap();
    let html = std::fs::read_to_string(root.path().join("report.html")).unwrap();
    assert!(html.contains("Tasks without a valid CPU interval"));
    assert!(html.contains("NOT CPU spent during capture"));
    assert!(html.contains("&lt;churning &amp; task&gt;"));
    assert!(!html.contains("<churning & task>"));
    assert!(s.threads[0].cpu_percent_one_core.is_none());
}

#[test]
fn legacy_protocol_defaults_and_missing_phases_remain_explicit() {
    let a = manifest();
    let mut b = a.clone();
    b.settings["include_threads"] = false.into();
    assert_eq!(
        artifacts::comparison_context(&a, &[]),
        artifacts::comparison_context(&b, &[])
    );
    b.settings["include_threads"] = true.into();
    assert_ne!(
        artifacts::comparison_context(&a, &[]),
        artifacts::comparison_context(&b, &[])
    );
    let mut sb = summary(&b, 50.0, 2.0);
    sb.resources.clear();
    let result = comparison::scopes(&a, &b, &summary(&a, 50.0, 2.0), &sb);
    assert!(!result.deltas.is_empty());
    assert!(
        result
            .deltas
            .iter()
            .all(|r| r["candidate"].is_null() && r["absolute_delta"].is_null())
    );
}
