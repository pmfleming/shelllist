use crate::{
    model::{Counter, GpuClient, Metric},
    procfs,
};
use anyhow::{Context, Result, ensure};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    os::unix::fs::MetadataExt,
};

pub fn parse(text: &str, fallback_device: &str) -> Result<Option<GpuClient>> {
    let fields = procfs::fields(text);
    let Some(driver) = fields.get("drm-driver") else {
        return Ok(None);
    };
    let mut client = GpuClient {
        driver: (*driver).into(),
        device: fields
            .get("drm-pdev")
            .copied()
            .unwrap_or(fallback_device)
            .into(),
        client_id: fields
            .get("drm-client-id")
            .context("DRM client ID unavailable")?
            .parse()?,
        ..Default::default()
    };
    ensure!(!client.device.is_empty(), "DRM device identity unavailable");
    for (key, value) in fields {
        if let Some(engine) = key.strip_prefix("drm-engine-capacity-") {
            let capacity = value.parse()?;
            ensure!(capacity > 0, "invalid engine capacity");
            client.capacities.insert(engine.into(), capacity);
        } else if let Some(engine) = key.strip_prefix("drm-engine-") {
            let parts: Vec<_> = value.split_whitespace().collect();
            ensure!(
                parts.len() == 2 && parts[1] == "ns",
                "unsupported DRM engine units"
            );
            client.engines_ns.insert(engine.into(), parts[0].parse()?);
        } else if [
            "drm-memory-",
            "drm-total-",
            "drm-resident-",
            "drm-shared-",
            "drm-purgeable-",
            "drm-active-",
        ]
        .iter()
        .any(|prefix| key.starts_with(prefix))
        {
            client
                .memory_bytes
                .insert(key.into(), procfs::bytes(value)?);
        }
    }
    Ok(Some(client))
}

pub fn collect(pid: u32, seen: &mut BTreeSet<String>) -> (Vec<GpuClient>, Option<String>) {
    let entries = match fs::read_dir(format!("/proc/{pid}/fdinfo")) {
        Ok(entries) => entries,
        Err(e) => return (vec![], Some(format!("fdinfo inaccessible: {e}"))),
    };
    let mut clients: BTreeMap<String, GpuClient> = BTreeMap::new();
    let mut issues = Vec::new();
    for entry in entries {
        let result = (|| -> Result<Option<GpuClient>> {
            let entry = entry?;
            let text = fs::read_to_string(entry.path())?;
            if !text.contains("drm-driver:") {
                return Ok(None);
            }
            let fd = format!("/proc/{pid}/fd/{}", entry.file_name().to_string_lossy());
            let device = fs::metadata(fd)
                .map(|m| format!("rdev:{}", m.rdev()))
                .unwrap_or_default();
            parse(&text, &device)
        })();
        match result {
            Ok(Some(c)) => {
                // Duplicate fd reads can differ because the GPU is running; keep one full,
                // latest snapshot, never sum aliased clients.
                clients.insert(c.key(), c);
            }
            Ok(None) => (),
            Err(e) => issues.push(e.to_string()),
        }
    }
    let had_clients = !clients.is_empty();
    let clients: Vec<_> = clients
        .into_iter()
        .filter_map(|(key, c)| seen.insert(key).then_some(c))
        .collect();
    if !issues.is_empty() {
        issues.truncate(4);
    }
    if clients.is_empty() {
        issues.push(
            if had_clients {
                "shared DRM clients already reported under another process"
            } else {
                "no readable supported DRM clients; GPU usage unavailable"
            }
            .into(),
        );
    }
    (clients, (!issues.is_empty()).then(|| issues.join("; ")))
}

pub fn derive(current: &mut GpuClient, previous: Option<&GpuClient>, seconds: f64) {
    current.interval_s = previous.map(|_| seconds);
    for (engine, now) in &current.engines_ns {
        let delta = previous
            .and_then(|p| p.engines_ns.get(engine))
            .and_then(|old| now.checked_sub(*old));
        current.busy_ns.insert(
            engine.clone(),
            match delta {
                Some(n) => Counter::new(n, "ns", "DRM fdinfo engine delta"),
                None => Counter::missing(
                    "ns",
                    "DRM fdinfo engine delta",
                    "first observation, missing prior counter, or reset",
                ),
            },
        );
        // The common DRM fdinfo ABI defines an omitted capacity as one engine.
        let capacity = current.capacities.get(engine).copied().unwrap_or(1);
        let stable_capacity =
            previous.is_some_and(|p| p.capacities.get(engine).copied().unwrap_or(1) == capacity);
        let percent = delta.map(|n| n as f64 / (seconds * 1e9 * capacity as f64) * 100.0);
        let metric = match percent {
            Some(p) if stable_capacity && seconds > 0.0 && p.is_finite() && p <= 100.5 => {
                Metric::new(
                    p,
                    "% engine capacity",
                    "DRM fdinfo; absent capacity = 1 per common ABI",
                )
            }
            _ => Metric::missing(
                "% engine capacity",
                "DRM fdinfo",
                "missing/reset counter, changed capacity, or implausible delta",
            ),
        };
        current.utilization.insert(engine.clone(), metric);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const FD: &str = "drm-driver: amdgpu\ndrm-client-id: 9\ndrm-pdev: 0000:01:00.0\ndrm-engine-gfx: 500000000 ns\ndrm-memory-vram: 12 KiB\ndrm-shared-vram: 0\n";
    #[test]
    fn parse_units_capacity_and_reset() {
        let previous = parse(FD, "").unwrap().unwrap();
        assert_eq!(previous.memory_bytes["drm-memory-vram"], 12288);
        let mut current = previous.clone();
        current.engines_ns.insert("gfx".into(), 750000000);
        derive(&mut current, Some(&previous), 1.0);
        assert_eq!(current.utilization["gfx"].value, Some(25.0));
        current.engines_ns.insert("gfx".into(), 1);
        derive(&mut current, Some(&previous), 1.0);
        assert!(current.utilization["gfx"].value.is_none());
        assert!(parse(&FD.replace(" ns", " cycles"), "").is_err());
        assert!(parse("drm-driver: test\n", "").is_err());
        assert!(parse("pos: 0\n", "").unwrap().is_none());
    }
    #[test]
    fn identities_deduplicate_aliases_not_devices() {
        let a = parse(FD, "").unwrap().unwrap();
        let b = parse(&FD.replace("01:00", "02:00"), "").unwrap().unwrap();
        let mut seen = BTreeSet::new();
        assert!(seen.insert(a.key()));
        assert!(!seen.insert(a.key()));
        assert!(seen.insert(b.key()));
    }
}
