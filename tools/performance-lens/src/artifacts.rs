use crate::{
    model::{Event, Manifest, SCHEMA, Sample, Summary},
    procfs, report, scenarios,
};
use anyhow::{Context, Result, ensure};
use serde::{Serialize, de::DeserializeOwned};
use std::{
    collections::BTreeMap,
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Write},
    os::unix::fs::{DirBuilderExt, OpenOptionsExt},
    path::{Path, PathBuf},
};

pub const MAX_RAW_BYTES: u64 = 128 * 1024 * 1024;

/// Reject a complete event before writing if it would exceed the run's event budget.
/// Each event is submitted as a single newline-terminated buffer.
pub struct EventFile {
    file: File,
    written: u64,
}
impl EventFile {
    pub fn new(file: File) -> Self {
        Self { file, written: 0 }
    }
}
impl Write for EventFile {
    fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
        if self.written + bytes.len() as u64 > MAX_RAW_BYTES {
            return Err(std::io::Error::other(
                "event artifact budget reached (128 MiB)",
            ));
        }
        let n = self.file.write(bytes)?;
        self.written += n as u64;
        Ok(n)
    }
    fn flush(&mut self) -> std::io::Result<()> {
        self.file.flush()
    }
}
#[cfg(test)]
#[test]
fn event_limit_does_not_write_a_partial_row() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("events.jsonl");
    let mut file = EventFile::new(raw_file(&path).unwrap());
    file.written = MAX_RAW_BYTES - 1;
    assert!(file.write_all(b"{}\n").is_err());
    assert_eq!(std::fs::metadata(&path).unwrap().len(), 0);
}

pub fn atomic_json(path: &Path, value: &impl Serialize) -> Result<()> {
    atomic_write(path, &serde_json::to_vec_pretty(value)?)
}
pub fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    let temp = path.with_extension(format!("tmp-{}", std::process::id()));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&temp)?;
    let result = (|| {
        file.write_all(bytes)?;
        file.sync_all()?;
        fs::rename(&temp, path)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(temp);
    }
    result
}

pub fn create(root: &Path) -> Result<PathBuf> {
    fs::create_dir_all(root)?;
    let prefix = format!("{}-{}", scenarios::unix_ms(), std::process::id());
    for n in 0..100 {
        let path = root.join(format!("{prefix}-{n}"));
        match fs::DirBuilder::new().mode(0o700).create(&path) {
            Ok(()) => return Ok(path),
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(e.into()),
        }
    }
    anyhow::bail!("cannot allocate unique run directory")
}
pub fn raw_file(path: &Path) -> Result<File> {
    Ok(OpenOptions::new()
        .create_new(true)
        .write(true)
        .mode(0o600)
        .open(path)?)
}

fn read_lines<T: DeserializeOwned>(path: &Path) -> Result<Vec<T>> {
    ensure!(
        fs::metadata(path)?.len() <= MAX_RAW_BYTES,
        "raw artifact exceeds 128 MiB"
    );
    let mut out = Vec::new();
    let mut reader = BufReader::new(File::open(path)?);
    let mut line = String::new();
    loop {
        line.clear();
        if reader.read_line(&mut line)? == 0 {
            break;
        }
        ensure!(
            line.ends_with('\n'),
            "truncated JSONL in {}",
            path.display()
        );
        ensure!(!line.trim().is_empty(), "empty measurement row");
        out.push(serde_json::from_str(&line).with_context(|| {
            format!("invalid JSONL row {} in {}", out.len() + 1, path.display())
        })?);
        ensure!(out.len() <= 500_000, "too many measurement rows");
    }
    Ok(out)
}

pub fn raw(path: &Path, manifest: &Manifest) -> Result<(Vec<Sample>, Vec<Event>)> {
    let samples: Vec<Sample> = read_lines(&path.join("samples.jsonl"))?;
    let events: Vec<Event> = read_lines(&path.join("events.jsonl"))?;
    let mut elapsed = 0.0;
    for (index, s) in samples.iter().enumerate() {
        ensure!(
            s.sequence == index as u64 && s.elapsed_s.is_finite() && s.elapsed_s >= elapsed,
            "invalid sample order/timestamp"
        );
        elapsed = s.elapsed_s;
        ensure!(
            if let Some(path) = &s.cgroup {
                s.pid == 0
                    && s.start_ticks == 0
                    && s.threads.is_none()
                    && manifest
                        .cgroups
                        .iter()
                        .any(|g| g.label == s.label && &g.path == path)
            } else {
                manifest.targets.iter().any(|t| {
                    t.label == s.label
                        && t.identity.pid == s.pid
                        && t.identity.start_ticks == s.start_ticks
                })
            },
            "sample target absent from manifest"
        );
        ensure!(
            s.interval_s.is_none_or(|s| s > 0.0 && s.is_finite()),
            "invalid sample interval"
        );
        if let Some(snapshot) = &s.threads {
            ensure!(
                s.error.is_none(),
                "thread observations on lost process identity"
            );
            ensure!(
                snapshot.tasks.len() <= crate::threads::MAX_TASKS,
                "too many task observations"
            );
            let mut tids = std::collections::BTreeSet::new();
            for t in &snapshot.tasks {
                ensure!(
                    t.tid > 0 && tids.insert(t.tid),
                    "invalid or duplicate task ID"
                );
                ensure!(
                    t.elapsed_s.is_finite() && t.elapsed_s >= s.elapsed_s,
                    "invalid task timestamp"
                );
                ensure!(
                    t.interval_s.is_none_or(|dt| dt.is_finite() && dt > 0.0),
                    "invalid task interval"
                );
                ensure!(
                    t.cpu_percent.value.is_some() == t.interval_s.is_some(),
                    "task CPU missing interval"
                );
                ensure!(
                    t.cpu_delta_ticks.is_none_or(|delta| delta <= t.cpu_ticks),
                    "task delta exceeds lifetime CPU"
                );
                ensure!(
                    !t.born_since_previous
                        || (t.cpu_delta_ticks == Some(t.cpu_ticks) && t.interval_s.is_some()),
                    "invalid newborn task baseline"
                );
                ensure!(
                    snapshot
                        .elapsed_s
                        .is_none_or(|end| end.is_finite() && end >= t.elapsed_s),
                    "invalid task snapshot endpoint"
                );
            }
        }
        for c in s.counters.values() {
            ensure!(
                c.value.is_some() != c.reason.is_some(),
                "counter must have either value or unavailable reason"
            );
        }
        for m in s
            .rates
            .values()
            .chain(s.gpu.iter().flat_map(|g| g.utilization.values()))
            .chain(
                s.threads
                    .iter()
                    .flat_map(|snapshot| snapshot.tasks.iter().map(|t| &t.cpu_percent)),
            )
        {
            ensure!(
                m.value.is_some() != m.reason.is_some(),
                "metric must have either value or unavailable reason"
            );
            ensure!(
                m.value.is_none_or(|v| v.is_finite() && v >= 0.0),
                "invalid numeric metric"
            );
        }
    }
    let mut elapsed = 0.0;
    let mut starts = std::collections::BTreeSet::new();
    let mut ends = std::collections::BTreeSet::new();
    for e in &events {
        ensure!(
            e.elapsed_s.is_finite() && e.elapsed_s >= elapsed,
            "invalid event timestamp"
        );
        elapsed = e.elapsed_s;
        if e.kind == "trial_started" {
            ensure!(starts.insert(e.trial), "duplicate trial start");
        }
        if e.kind == "trial_finished" {
            ensure!(
                starts.contains(&e.trial) && ends.insert(e.trial),
                "orphan or duplicate trial completion"
            );
        }
    }
    if manifest.status == "complete" {
        ensure!(!samples.is_empty(), "complete artifact has no samples");
        if manifest.scenario == "capture" {
            ensure!(
                samples.iter().any(|s| s.label == "ui-host"
                    && s.phase == "capture"
                    && s.rates
                        .get("cpu_percent")
                        .is_some_and(|m| m.value.is_some())),
                "capture too short or no valid primary CPU interval"
            );
        }
        ensure!(starts == ends, "complete artifact has unfinished trials");
        if manifest.scenario == "warm-open" {
            let expected = manifest.settings["trials"]
                .as_u64()
                .context("missing expected trials")?
                + 1;
            ensure!(
                starts.len() as u64 == expected && starts.iter().copied().eq(0..expected as u32),
                "missing expected trials"
            );
            ensure!(
                events
                    .iter()
                    .filter(|e| e.kind == "trial_finished")
                    .all(|e| e.data["status"] == "ok"),
                "complete run contains a failed trial"
            );
        }
    }
    Ok((samples, events))
}

pub fn finish(path: &Path, manifest: &mut Manifest) -> Result<Summary> {
    manifest.finished_unix_ms = Some(scenarios::unix_ms());
    for name in ["samples.jsonl", "events.jsonl"] {
        manifest
            .hashes
            .insert(name.into(), procfs::hash_file(&path.join(name))?);
    }
    atomic_json(&path.join("manifest.json"), manifest)?;
    let (samples, events) = match raw(path, manifest) {
        Ok(raw) => raw,
        Err(error) => {
            manifest.status = "failed".into();
            manifest.error = Some(format!("artifact validation: {error:#}"));
            atomic_json(&path.join("manifest.json"), manifest)?;
            return Err(error);
        }
    };
    if samples.iter().any(|s| s.error.is_some()) && manifest.status == "complete" {
        manifest.status = "partial".into();
        manifest.error = Some("one or more tracked processes were unavailable".into());
    }
    atomic_json(&path.join("manifest.json"), manifest)?;
    let summary = report::summarize(manifest, &samples, &events);
    report::write(path, manifest, &summary, &samples, &events)?;
    Ok(summary)
}

pub fn load(path: &Path) -> Result<(Manifest, Vec<Sample>, Vec<Event>)> {
    let manifest_path = path.join("manifest.json");
    ensure!(
        fs::metadata(&manifest_path)?.len() < 1024 * 1024,
        "manifest too large"
    );
    let manifest: Manifest = serde_json::from_slice(&fs::read(manifest_path)?)?;
    ensure!(
        manifest.schema_version == SCHEMA,
        "unsupported artifact schema"
    );
    ensure!(
        ["complete", "partial", "failed"].contains(&manifest.status.as_str()),
        "run not finalized; raw files remain diagnostic evidence only"
    );
    ensure!(manifest.finished_unix_ms.is_some(), "missing run end");
    for name in ["samples.jsonl", "events.jsonl"] {
        ensure!(
            manifest.hashes.get(name) == Some(&procfs::hash_file(&path.join(name))?),
            "{name} content fingerprint mismatch"
        );
    }
    let (samples, events) = raw(path, &manifest)?;
    Ok((manifest, samples, events))
}

/// Only auto-discovered labels carry an ephemeral PID suffix. User labels such
/// as "worker:2" are stable roles and must not be collapsed together.
pub fn scope_role(label: &str) -> &str {
    if label.starts_with("related:") || label.starts_with("ui-service-member:") {
        label
            .rsplit_once(':')
            .filter(|(_, tail)| tail.parse::<u32>().is_ok())
            .map_or(label, |(head, _)| head)
    } else {
        label
    }
}

pub fn comparison_context(
    manifest: &Manifest,
    changed_scopes: &[String],
) -> BTreeMap<String, String> {
    let mut result = manifest.context.clone();
    result.insert("scenario".into(), manifest.scenario.clone());
    result.insert("schema".into(), manifest.schema_version.to_string());
    result.insert(
        "ticks_per_second".into(),
        manifest.ticks_per_second.to_string(),
    );
    result.insert("lens_version".into(), manifest.lens_version.clone());
    if !changed_scopes.iter().any(|r| r == "lens-observer") {
        result.insert("lens_sha256".into(), manifest.lens_sha256.clone());
    }
    let mut settings = manifest.settings.clone();
    if let Some(object) = settings.as_object_mut() {
        object.remove("config_identity");
        object.remove("quickshell_path");
        // Additive optional diagnostic: old captures did not collect tasks.
        object
            .entry("include_cgroups")
            .or_insert(serde_json::json!(false));
        object
            .entry("include_threads")
            .or_insert(serde_json::json!(false));
        let cadence = if object["include_threads"] == true {
            serde_json::json!("detail")
        } else {
            serde_json::Value::Null
        };
        object.entry("thread_cadence").or_insert(cadence);
    }
    result.insert("protocol".into(), settings.to_string());
    // Related identities must match by executable and role, not ephemeral PID.
    let mut roles: Vec<_> = manifest
        .targets
        .iter()
        .map(|t| {
            let role = scope_role(&t.label);
            let hash = if role == "ui-host" || changed_scopes.iter().any(|r| r == role) {
                "candidate-allowed"
            } else {
                &t.identity.executable_sha256
            };
            format!("{role}:{hash}")
        })
        .collect();
    roles.sort();
    result.insert("process_scopes".into(), roles.join(","));
    let mut groups: Vec<_> = manifest
        .cgroups
        .iter()
        .map(|g| format!("{}:{}", g.label, g.path))
        .collect();
    groups.sort();
    result.insert("cgroup_scopes".into(), groups.join(","));
    result
}
