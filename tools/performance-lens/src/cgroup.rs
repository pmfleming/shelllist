//! Opt-in cgroup v2 service accounting. Never add these hierarchical totals to
//! process totals. Directory identity is fenced; replacement is not reattached.
use crate::{
    model::{CgroupTarget, Counter, Metric, Sample, Target},
    target,
};
use anyhow::{Context, Result, ensure};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    os::unix::fs::MetadataExt,
    path::Path,
    time::Instant,
};

pub fn discover(targets: &[Target], warnings: &mut Vec<String>) -> Vec<CgroupTarget> {
    let mut seen = BTreeSet::new();
    let mut groups = Vec::new();
    for t in targets.iter().filter(|t| t.label != "lens-observer") {
        let result = (|| -> Result<CgroupTarget> {
            let group = target::cgroup(t.identity.pid)?;
            ensure!(
                group.starts_with('/') && group != "/" && !group.split('/').any(|s| s == ".."),
                "unsafe/root cgroup"
            );
            let path = Path::new("/sys/fs/cgroup")
                .join(group.trim_start_matches('/'))
                .canonicalize()?;
            ensure!(
                path.starts_with("/sys/fs/cgroup") && path != Path::new("/sys/fs/cgroup"),
                "outside cgroup mount"
            );
            let metadata = path.metadata()?;
            Ok(CgroupTarget {
                label: format!("cgroup:{group}"),
                path: path.to_string_lossy().into(),
                device: metadata.dev(),
                inode: metadata.ino(),
            })
        })();
        match result {
            Ok(group) if seen.insert(group.path.clone()) => groups.push(group),
            Ok(_) => {}
            Err(error) => warnings.push(format!("{} cgroup unavailable: {error:#}", t.label)),
        }
    }
    warnings.push("Cgroup counters include all current and short-lived descendant tasks, including other clients' work. They overlap process scopes and possibly other cgroups: do not sum them. Cgroup memory includes charged cache/kernel memory, not RSS. Directory replacement ends coverage; no automatic reattachment.".into());
    groups
}

fn verify(target: &CgroupTarget) -> Result<()> {
    let metadata = fs::metadata(&target.path)?;
    ensure!(
        metadata.dev() == target.device && metadata.ino() == target.inode,
        "cgroup replaced"
    );
    Ok(())
}

fn pairs(text: &str) -> Result<BTreeMap<String, u64>> {
    let mut values = BTreeMap::new();
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        let key = fields.next().context("missing key")?;
        let value = fields.next().context("missing value")?.parse()?;
        ensure!(
            fields.next().is_none() && values.insert(key.into(), value).is_none(),
            "invalid/duplicate cgroup field"
        );
    }
    Ok(values)
}

fn read_fields(root: &Path, file: &str) -> Result<BTreeMap<String, u64>> {
    pairs(&fs::read_to_string(root.join(file))?)
}

fn field(values: &Result<BTreeMap<String, u64>>, key: &str, unit: &str, source: &str) -> Counter {
    match values {
        Ok(values) => values
            .get(key)
            .map(|v| Counter::new(*v, unit, source))
            .unwrap_or_else(|| Counter::missing(unit, source, "field unavailable")),
        Err(error) => Counter::missing(unit, source, error.to_string()),
    }
}

pub fn collect(
    target: &CgroupTarget,
    sequence: u64,
    start: Instant,
    phase: &str,
    phase_sequence: u64,
) -> Sample {
    let begin = Instant::now();
    let mut sample = Sample {
        sequence,
        elapsed_s: start.elapsed().as_secs_f64(),
        phase: phase.into(),
        phase_sequence,
        label: target.label.clone(),
        pid: 0,
        start_ticks: 0,
        cgroup: Some(target.path.clone()),
        interval_s: None,
        counters: BTreeMap::new(),
        rates: BTreeMap::new(),
        gpu: vec![],
        gpu_reason: Some("not collected for cgroups".into()),
        threads: None,
        error: None,
        collection_ms: 0.0,
        late_by_ms: 0.0,
    };
    let result = (|| -> Result<()> {
        verify(target)?;
        let root = Path::new(&target.path);
        let cpu = read_fields(root, "cpu.stat");
        sample.counters.insert(
            "cpu_usage_usec".into(),
            field(&cpu, "usage_usec", "us", "cgroup v2 cpu.stat"),
        );
        let memory = fs::read_to_string(root.join("memory.current"))
            .map_err(anyhow::Error::from)
            .and_then(|s| Ok(s.trim().parse::<u64>()?));
        sample.counters.insert(
            "memory_current_bytes".into(),
            match memory {
                Ok(n) => Counter::new(n, "bytes", "cgroup v2 memory.current"),
                Err(e) => Counter::missing("bytes", "cgroup v2 memory.current", e.to_string()),
            },
        );
        // Keep all integer memory.stat fields; only documented byte gauges are
        // labelled bytes, other fields remain counts rather than invented RSS.
        match read_fields(root, "memory.stat") {
            Ok(values) => {
                for (key, value) in values {
                    let unit = if matches!(
                        key.as_str(),
                        "anon"
                            | "file"
                            | "kernel"
                            | "kernel_stack"
                            | "pagetables"
                            | "sec_pagetables"
                            | "percpu"
                            | "sock"
                            | "vmalloc"
                            | "shmem"
                            | "zswap"
                            | "zswapped"
                            | "file_mapped"
                            | "file_dirty"
                            | "file_writeback"
                            | "swapcached"
                            | "anon_thp"
                            | "file_thp"
                            | "shmem_thp"
                            | "inactive_anon"
                            | "active_anon"
                            | "inactive_file"
                            | "active_file"
                            | "unevictable"
                            | "slab_reclaimable"
                            | "slab_unreclaimable"
                            | "slab"
                    ) {
                        "bytes"
                    } else if key.starts_with("pg")
                        || key.starts_with("workingset_")
                        || key.starts_with("thp_")
                    {
                        "count"
                    } else {
                        "kernel-defined units"
                    };
                    sample.counters.insert(
                        format!("memory_stat.{key}"),
                        Counter::new(value, unit, "cgroup v2 memory.stat"),
                    );
                }
            }
            Err(e) => {
                sample.counters.insert(
                    "memory_stat".into(),
                    Counter::missing("fields", "cgroup v2 memory.stat", e.to_string()),
                );
            }
        }
        let io = fs::read_to_string(root.join("io.stat"))
            .map_err(anyhow::Error::from)
            .and_then(|text| io_fields(&text));
        match io {
            Ok(values) => sample.counters.extend(values),
            Err(e) => {
                for key in ["read_bytes", "write_bytes"] {
                    sample.counters.insert(
                        key.into(),
                        Counter::missing("bytes", "cgroup v2 io.stat", e.to_string()),
                    );
                }
            }
        }
        for resource in ["cpu", "memory", "io"] {
            let source = format!("cgroup v2 {resource}.pressure");
            let pressure = fs::read_to_string(root.join(format!("{resource}.pressure")))
                .map_err(anyhow::Error::from)
                .and_then(|text| pressure_fields(&text));
            for kind in ["some", "full"] {
                sample.counters.insert(
                    format!("psi.{resource}.{kind}_usec"),
                    field(&pressure, kind, "us", &source),
                );
            }
        }
        verify(target)?;
        Ok(())
    })();
    if let Err(e) = result {
        sample.counters.clear();
        sample.error = Some(e.to_string());
    }
    sample.collection_ms = begin.elapsed().as_secs_f64() * 1000.0;
    sample
}

fn io_fields(text: &str) -> Result<BTreeMap<String, Counter>> {
    let mut values = BTreeMap::new();
    let (mut read, mut write) = (0u64, 0u64);
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        let device = fields.next().context("missing I/O device")?;
        ensure!(
            device
                .split_once(':')
                .is_some_and(|(a, b)| a.parse::<u32>().is_ok() && b.parse::<u32>().is_ok()),
            "invalid I/O device"
        );
        let mut found = BTreeMap::new();
        for field in fields {
            let (key, value) = field.split_once('=').context("invalid I/O field")?;
            ensure!(
                found.insert(key, value.parse::<u64>()?).is_none(),
                "duplicate I/O field"
            );
        }
        read = read
            .checked_add(*found.get("rbytes").context("missing rbytes")?)
            .context("I/O overflow")?;
        write = write
            .checked_add(*found.get("wbytes").context("missing wbytes")?)
            .context("I/O overflow")?;
        for (key, value) in found {
            ensure!(
                values
                    .insert(
                        format!("io.{device}.{key}"),
                        Counter::new(
                            value,
                            if key.ends_with("bytes") {
                                "bytes"
                            } else {
                                "count"
                            },
                            "cgroup v2 io.stat"
                        )
                    )
                    .is_none(),
                "duplicate I/O device"
            );
        }
    }
    // A readable empty io.stat means no accounted I/O, not unsupported.
    values.insert(
        "read_bytes".into(),
        Counter::new(read, "bytes", "cgroup v2 io.stat"),
    );
    values.insert(
        "write_bytes".into(),
        Counter::new(write, "bytes", "cgroup v2 io.stat"),
    );
    Ok(values)
}

fn pressure_fields(text: &str) -> Result<BTreeMap<String, u64>> {
    let mut values = BTreeMap::new();
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        let kind = fields.next().context("missing PSI kind")?;
        let total = fields
            .find_map(|s| s.strip_prefix("total="))
            .context("missing PSI total")?
            .parse()?;
        ensure!(
            values.insert(kind.into(), total).is_none(),
            "duplicate PSI kind"
        );
    }
    Ok(values)
}

pub fn derive(now: &mut Sample, previous: Option<&Sample>) {
    let previous = previous.filter(|old| {
        old.phase_sequence == now.phase_sequence
            && old.phase == now.phase
            && old.error.is_none()
            && now.error.is_none()
    });
    now.interval_s = previous
        .map(|old| now.elapsed_s - old.elapsed_s)
        .filter(|dt| *dt > 0.0);
    for (key, counter) in &now.counters {
        let (name, scale, unit) = match key.as_str() {
            "cpu_usage_usec" => ("cpu_percent".into(), 0.0001, "% one core"),
            "read_bytes" | "write_bytes" => (format!("{key}_per_second"), 1.0, "bytes/s"),
            _ if key.starts_with("psi.") => {
                (format!("{key}_percent"), 0.0001, "% stalled wall time")
            }
            _ => continue,
        };
        let value = (|| {
            let old = previous?;
            if key == "read_bytes" || key == "write_bytes" {
                // Device disappearance/appearance breaks aggregate I/O continuity.
                if !now
                    .counters
                    .keys()
                    .filter(|k| k.starts_with("io."))
                    .eq(old.counters.keys().filter(|k| k.starts_with("io.")))
                {
                    return None;
                }
                for (k, c) in now.counters.iter().filter(|(k, _)| k.starts_with("io.")) {
                    c.value?.checked_sub(old.counters.get(k)?.value?)?;
                }
            }
            let delta = counter.value?.checked_sub(old.counters.get(key)?.value?)?;
            Some(delta as f64 * scale / now.interval_s?)
        })();
        now.rates.insert(name, match value {
            Some(value) => Metric::new(value, unit, &format!("{} delta", counter.source)),
            None => Metric::missing(unit, &format!("{} delta", counter.source), "first observation, phase/identity loss, missing field, topology change or reset"),
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn service_files_cover_cpu_memory_io_pressure_and_fence_replacement() {
        let root = tempfile::tempdir().unwrap();
        fs::write(root.path().join("cpu.stat"), "usage_usec 1000000\n").unwrap();
        fs::write(root.path().join("memory.current"), "4096\n").unwrap();
        fs::write(root.path().join("memory.stat"), "anon 1024\npgfault 3\n").unwrap();
        fs::write(
            root.path().join("io.stat"),
            "8:0 rbytes=100 wbytes=200 rios=1 wios=2\n",
        )
        .unwrap();
        fs::write(
            root.path().join("cpu.pressure"),
            "some avg10=0.0 total=1000\n",
        )
        .unwrap();
        let meta = root.path().metadata().unwrap();
        let mut target = CgroupTarget {
            label: "cgroup:fixture".into(),
            path: root.path().to_string_lossy().into(),
            device: meta.dev(),
            inode: meta.ino(),
        };
        let start = Instant::now();
        let mut old = collect(&target, 0, start, "capture", 1);
        old.elapsed_s = 1.0;
        assert_eq!(old.counters["memory_stat.anon"].unit, "bytes");
        assert_eq!(old.counters["memory_stat.pgfault"].unit, "count");
        assert!(old.counters["psi.cpu.full_usec"].value.is_none());
        fs::write(root.path().join("cpu.stat"), "usage_usec 1500000\n").unwrap();
        let mut now = collect(&target, 1, start, "capture", 1);
        now.elapsed_s = 2.0;
        derive(&mut now, Some(&old));
        assert_eq!(now.rates["cpu_percent"].value, Some(50.0));
        assert_eq!(now.rates["write_bytes_per_second"].value, Some(0.0));
        now.counters.get_mut("cpu_usage_usec").unwrap().value = Some(0);
        derive(&mut now, Some(&old));
        assert!(now.rates["cpu_percent"].value.is_none());
        now.counters.remove("io.8:0.wbytes");
        derive(&mut now, Some(&old));
        assert!(now.rates["write_bytes_per_second"].value.is_none());
        now.phase_sequence += 1;
        derive(&mut now, Some(&old));
        assert!(now.interval_s.is_none());
        target.inode += 1;
        assert!(collect(&target, 2, start, "capture", 1).error.is_some());
        assert!(io_fields("8:0 wbytes=2").is_err());
        assert_eq!(io_fields("").unwrap()["write_bytes"].value, Some(0));
    }
}
