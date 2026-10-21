use crate::{
    command::INTERRUPTED,
    drm,
    model::{Metric, Sample, Target},
    procfs,
};
use anyhow::{Result, bail};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::File,
    io::{BufWriter, Write},
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

#[derive(Clone)]
pub struct Control {
    pub stop: Arc<AtomicBool>,
    pub phase: Arc<Mutex<(String, u64)>>,
}
impl Control {
    pub fn new(phase: &str) -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            phase: Arc::new(Mutex::new((phase.into(), 0))),
        }
    }
    pub fn phase(&self, value: &str) {
        let mut phase = self.phase.lock().unwrap();
        phase.0 = value.into();
        phase.1 += 1;
    }
}

pub fn rates(now: &Sample, previous: Option<&Sample>, ticks: u64) -> BTreeMap<String, Metric> {
    let mut result = BTreeMap::new();
    for (key, unit, scale) in [
        ("cpu_ticks", "% one core", 100.0 / ticks as f64),
        ("read_bytes", "bytes/s", 1.0),
        ("write_bytes", "bytes/s", 1.0),
        ("rchar", "bytes/s", 1.0),
        ("wchar", "bytes/s", 1.0),
        ("minor_faults", "count/s", 1.0),
        ("major_faults", "count/s", 1.0),
    ] {
        let value = previous
            .filter(|p| {
                p.phase_sequence == now.phase_sequence
                    && p.phase == now.phase
                    && p.error.is_none()
                    && now.error.is_none()
            })
            .and_then(|p| {
                let delta = now
                    .counters
                    .get(key)?
                    .value?
                    .checked_sub(p.counters.get(key)?.value?)?;
                let seconds = now.elapsed_s - p.elapsed_s;
                (seconds > 0.0).then_some(delta as f64 * scale / seconds)
            });
        let name = if key == "cpu_ticks" {
            "cpu_percent".into()
        } else {
            format!("{key}_per_second")
        };
        result.insert(name, match value {
            Some(value) => Metric::new(value, unit, &format!("proc delta: {key}")),
            None => Metric::missing(unit, &format!("proc delta: {key}"), "first observation, phase boundary, identity loss, missing field or counter reset"),
        });
    }
    result
}

pub fn collect(
    target: &Target,
    sequence: u64,
    start: Instant,
    phase: &str,
    heavy: bool,
    seen_gpu: &mut BTreeSet<String>,
) -> Sample {
    let begin = Instant::now();
    let mut sample = Sample {
        sequence,
        elapsed_s: start.elapsed().as_secs_f64(),
        phase: phase.into(),
        phase_sequence: 0,
        label: target.label.clone(),
        pid: target.identity.pid,
        start_ticks: target.identity.start_ticks,
        interval_s: None,
        counters: BTreeMap::new(),
        rates: BTreeMap::new(),
        gpu: vec![],
        gpu_reason: None,
        error: None,
        collection_ms: 0.0,
        late_by_ms: 0.0,
    };
    match procfs::counters(&target.identity, heavy) {
        Ok(counters) => {
            sample.counters = counters;
            if heavy {
                (sample.gpu, sample.gpu_reason) = drm::collect(target.identity.pid, seen_gpu);
            } else {
                sample.gpu_reason = Some("not sampled at this cadence".into());
            }
            if let Err(e) = procfs::verify(&target.identity) {
                sample.counters.clear();
                sample.gpu.clear();
                sample.error = Some(format!("identity lost during sample: {e:#}"));
            }
        }
        Err(e) => {
            sample.error = Some(format!("{e:#}"));
            sample.gpu_reason = Some("process unavailable".into());
        }
    }
    sample.collection_ms = begin.elapsed().as_secs_f64() * 1000.0;
    sample
}

pub fn run(
    file: File,
    targets: Vec<Target>,
    start: Instant,
    interval: Duration,
    detail_interval: Duration,
    ticks: u64,
    control: Control,
) -> Result<()> {
    let mut file = BufWriter::new(file);
    let mut prior = BTreeMap::<u32, Sample>::new();
    let mut heavy_prior = BTreeMap::<u32, Sample>::new();
    let mut due = start;
    let mut heavy_due = start;
    let mut seq = 0;
    loop {
        if control.stop.load(Ordering::Relaxed) || INTERRUPTED.load(Ordering::Relaxed) {
            break;
        }
        let now = Instant::now();
        if now < due {
            std::thread::sleep((due - now).min(Duration::from_millis(10)));
            continue;
        }
        let heavy = now >= heavy_due;
        if heavy {
            heavy_due = now + detail_interval;
        }
        let mut seen_gpu = BTreeSet::new();
        for target in &targets {
            let (phase, generation) = control.phase.lock().unwrap().clone();
            let mut sample = collect(target, seq, start, &phase, heavy, &mut seen_gpu);
            sample.phase_sequence = generation;
            sample.late_by_ms = now.saturating_duration_since(due).as_secs_f64() * 1000.0;
            let previous = prior.get(&target.identity.pid).filter(|p| {
                p.phase_sequence == sample.phase_sequence
                    && p.phase == sample.phase
                    && p.error.is_none()
                    && sample.error.is_none()
            });
            sample.interval_s = previous.map(|p| sample.elapsed_s - p.elapsed_s);
            sample.rates = rates(&sample, previous, ticks);
            if heavy {
                let previous = heavy_prior.get(&target.identity.pid).filter(|p| {
                    p.phase_sequence == sample.phase_sequence
                        && p.phase == sample.phase
                        && p.error.is_none()
                        && sample.error.is_none()
                });
                for client in &mut sample.gpu {
                    let old = previous.and_then(|p| p.gpu.iter().find(|c| c.key() == client.key()));
                    let seconds = previous
                        .map(|p| sample.elapsed_s - p.elapsed_s)
                        .unwrap_or(0.0);
                    drm::derive(client, old, seconds);
                }
                heavy_prior.insert(target.identity.pid, sample.clone());
            }
            serde_json::to_writer(&mut file, &sample)?;
            file.write_all(b"\n")?;
            seq += 1;
            if target.label == "ui-host" {
                if let Some(error) = &sample.error {
                    file.flush()?;
                    bail!("primary target lost: {error}");
                }
            }
            prior.insert(target.identity.pid, sample);
        }
        file.flush()?;
        if file.get_ref().metadata()?.len() > crate::artifacts::MAX_RAW_BYTES - 1024 * 1024 {
            bail!("raw sample budget reached (128 MiB); capture stopped");
        }
        due += interval;
        if due < Instant::now() {
            due = Instant::now() + interval;
        }
    }
    file.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn actual_intervals_resets_and_phases() {
        let target = Target {
            label: "test".into(),
            identity: procfs::identity(std::process::id()).unwrap(),
        };
        let mut a = collect(
            &target,
            0,
            Instant::now(),
            "idle",
            false,
            &mut BTreeSet::new(),
        );
        a.elapsed_s = 0.0;
        a.counters.get_mut("cpu_ticks").unwrap().value = Some(10);
        let mut b = a.clone();
        b.elapsed_s = 2.0;
        b.counters.get_mut("cpu_ticks").unwrap().value = Some(110);
        assert_eq!(rates(&b, Some(&a), 100)["cpu_percent"].value, Some(50.0));
        b.counters.get_mut("cpu_ticks").unwrap().value = Some(1);
        assert!(rates(&b, Some(&a), 100)["cpu_percent"].value.is_none());
        b.counters.get_mut("cpu_ticks").unwrap().value = Some(110);
        b.phase_sequence = a.phase_sequence + 1;
        assert!(rates(&b, Some(&a), 100)["cpu_percent"].value.is_none());
        b.phase = "other".into();
        assert!(rates(&b, Some(&a), 100)["cpu_percent"].value.is_none());
    }
}
