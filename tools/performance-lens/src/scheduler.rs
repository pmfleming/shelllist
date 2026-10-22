//! Optional per-task scheduler diagnostics. Context switches are not wakeups.
use crate::model::{Counter, Metric, Sample, TaskScheduler, ThreadSnapshot};
use std::{collections::BTreeMap, fs, path::Path};

pub fn collect(root: &Path, wait_accounting: bool) -> TaskScheduler {
    let mut counters = BTreeMap::new();
    let sched = fs::read_to_string(root.join("schedstat"));
    for (index, key) in [(0, "runtime_ns"), (1, "runqueue_wait_ns")] {
        let value = sched
            .as_ref()
            .ok()
            .and_then(|text| text.split_whitespace().nth(index)?.parse::<u64>().ok());
        let counter = if key == "runqueue_wait_ns" && !wait_accounting {
            Counter::missing(
                "ns",
                "proc/task/schedstat",
                "scheduler wait accounting disabled or unavailable",
            )
        } else {
            match value {
                Some(value) => Counter::new(value, "ns", "proc/task/schedstat"),
                None => Counter::missing("ns", "proc/task/schedstat", "file or field unavailable"),
            }
        };
        counters.insert(key.into(), counter);
    }
    let status = fs::read_to_string(root.join("status"));
    for key in ["voluntary_ctxt_switches", "nonvoluntary_ctxt_switches"] {
        let value = status.as_ref().ok().and_then(|text| {
            text.lines().find_map(|line| {
                let (name, value) = line.split_once(':')?;
                (name == key)
                    .then(|| value.trim().parse::<u64>().ok())
                    .flatten()
            })
        });
        counters.insert(
            key.into(),
            match value {
                Some(value) => Counter::new(value, "count", "proc/task/status"),
                None => Counter::missing("count", "proc/task/status", "file or field unavailable"),
            },
        );
    }
    TaskScheduler {
        counters,
        deltas: BTreeMap::new(),
    }
}

pub fn derive(now: &mut ThreadSnapshot, previous: Option<&ThreadSnapshot>) {
    let old: BTreeMap<_, _> = previous
        .into_iter()
        .flat_map(|s| &s.tasks)
        .map(|t| ((t.tid, t.start_ticks), t))
        .collect();
    for task in &mut now.tasks {
        let Some(scheduler) = &mut task.scheduler else {
            continue;
        };
        let previous = old
            .get(&(task.tid, task.start_ticks))
            .and_then(|t| t.scheduler.as_ref());
        for (key, value) in &scheduler.counters {
            let delta = value.value.and_then(|current| {
                task.interval_s?;
                let baseline = if task.born_since_previous {
                    0
                } else {
                    previous?.counters.get(key)?.value?
                };
                current.checked_sub(baseline)
            });
            scheduler.deltas.insert(
                key.clone(),
                match delta {
                    Some(delta) => {
                        Counter::new(delta, &value.unit, &format!("{} delta", value.source))
                    }
                    None => Counter::missing(
                        &value.unit,
                        &format!("{} delta", value.source),
                        "missing paired task counter, phase boundary or reset",
                    ),
                },
            );
        }
    }
}

pub fn aggregate(sample: &mut Sample) {
    for (key, rate, scale, unit) in [
        (
            "runtime_ns",
            "observed_task_cpu_percent",
            1e-7,
            "% one core",
        ),
        (
            "runqueue_wait_ns",
            "observed_task_runqueue_wait_ms_per_second",
            1e-6,
            "ms/s",
        ),
        (
            "voluntary_ctxt_switches",
            "observed_task_voluntary_switches_per_second",
            1.0,
            "count/s",
        ),
        (
            "nonvoluntary_ctxt_switches",
            "observed_task_nonvoluntary_switches_per_second",
            1.0,
            "count/s",
        ),
    ] {
        let value = (|| {
            let snapshot = sample.threads.as_ref()?;
            if snapshot.error.is_some() || snapshot.tasks.is_empty() {
                return None;
            }
            let total = snapshot.tasks.iter().try_fold(0u64, |sum, task| {
                sum.checked_add(task.scheduler.as_ref()?.deltas.get(key)?.value?)
            })?;
            Some(total as f64 * scale / sample.interval_s?)
        })();
        sample.rates.insert(
            rate.into(),
            match value {
                Some(value) => {
                    Metric::new(value, unit, "observed per-task deltas / process interval")
                }
                None => Metric::missing(
                    unit,
                    "observed per-task deltas / process interval",
                    "incomplete paired scheduler observations or disabled accounting",
                ),
            },
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn paired_and_newborn_scheduler_deltas_sum_threads_and_reject_resets() {
        let target = crate::model::Target {
            label: "fixture".into(),
            identity: crate::procfs::identity(std::process::id()).unwrap(),
        };
        let mut sample = crate::sampler::collect(
            &target,
            0,
            std::time::Instant::now(),
            "capture",
            false,
            crate::sampler::TaskDetail::Scheduler,
            &mut Default::default(),
        );
        let mut task = sample.threads.as_ref().unwrap().tasks[0].clone();
        task.interval_s = Some(1.0);
        task.scheduler.as_mut().unwrap().counters.insert(
            "runtime_ns".into(),
            Counter::new(1_000_000, "ns", "fixture"),
        );
        let old = ThreadSnapshot {
            tasks: vec![task.clone()],
            ..Default::default()
        };
        task.scheduler
            .as_mut()
            .unwrap()
            .counters
            .get_mut("runtime_ns")
            .unwrap()
            .value = Some(2_000_000);
        let mut born = task.clone();
        born.tid += 1;
        born.born_since_previous = true;
        let mut now = ThreadSnapshot {
            tasks: vec![task, born],
            ..Default::default()
        };
        derive(&mut now, Some(&old));
        sample.interval_s = Some(1.0);
        sample.threads = Some(now.clone());
        aggregate(&mut sample);
        assert!((sample.rates["observed_task_cpu_percent"].value.unwrap() - 0.3).abs() < 1e-9);
        now.tasks[0]
            .scheduler
            .as_mut()
            .unwrap()
            .counters
            .get_mut("runtime_ns")
            .unwrap()
            .value = Some(0);
        derive(&mut now, Some(&old));
        assert!(
            now.tasks[0].scheduler.as_ref().unwrap().deltas["runtime_ns"]
                .value
                .is_none()
        );
        now.tasks[1].born_since_previous = false;
        derive(&mut now, None);
        assert!(now.tasks.iter().all(|t| {
            t.scheduler.as_ref().unwrap().deltas["runtime_ns"]
                .value
                .is_none()
        }));
    }

    #[test]
    fn scheduler_precision_and_disabled_wait_are_independent_of_switch_counts() {
        let root = tempfile::tempdir().unwrap();
        fs::write(root.path().join("schedstat"), "1234567 8901234 4\n").unwrap();
        fs::write(
            root.path().join("status"),
            "voluntary_ctxt_switches:\t12\nnonvoluntary_ctxt_switches:\t7\n",
        )
        .unwrap();
        let sample = collect(root.path(), true);
        assert_eq!(sample.counters["runtime_ns"].value, Some(1234567));
        assert_eq!(sample.counters["runqueue_wait_ns"].value, Some(8901234));
        assert_eq!(sample.counters["voluntary_ctxt_switches"].value, Some(12));
        assert!(
            collect(root.path(), false).counters["runqueue_wait_ns"]
                .value
                .is_none()
        );
        fs::remove_file(root.path().join("status")).unwrap();
        assert!(
            collect(root.path(), true).counters["voluntary_ctxt_switches"]
                .value
                .is_none()
        );
    }
}
