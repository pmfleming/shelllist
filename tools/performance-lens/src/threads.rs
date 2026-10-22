//! Optional task-level localization, not stack profiling or an additive CPU total.
use crate::{
    model::{Metric, Sample, ThreadSample, ThreadSnapshot, ThreadSummary},
    procfs,
};
use anyhow::{Context, Result, ensure};
use std::{collections::BTreeMap, fs, path::Path, time::Instant};

pub const MAX_TASKS: usize = 1024;
const SOURCE: &str = "proc/task/stat delta";

pub fn collect(pid: u32, start: Instant, scheduler: bool) -> ThreadSnapshot {
    collect_at(Path::new(&format!("/proc/{pid}/task")), start, scheduler)
}

fn collect_at(root: &Path, start: Instant, scheduler: bool) -> ThreadSnapshot {
    let wait_accounting = scheduler
        && fs::read_to_string("/proc/sys/kernel/sched_schedstats")
            .is_ok_and(|text| text.trim() == "1");
    let mut snapshot = ThreadSnapshot::default();
    let result = (|| -> Result<()> {
        let mut tids = Vec::new();
        for entry in fs::read_dir(root)?.take(MAX_TASKS + 1) {
            let entry = entry?;
            let tid = entry.file_name().to_string_lossy().parse::<u32>()?;
            tids.push(tid);
        }
        ensure!(
            tids.len() <= MAX_TASKS,
            "thread limit exceeded (1024); no partial ranking collected"
        );
        tids.sort_unstable();
        for tid in tids {
            let elapsed_s = start.elapsed().as_secs_f64();
            let parsed = (|| -> Result<ThreadSample> {
                let text = fs::read_to_string(root.join(tid.to_string()).join("stat"))?;
                let stat = procfs::parse_stat(&text)?;
                let (head, _) = text.rsplit_once(')').context("missing task comm")?;
                let (_, name) = head.split_once('(').context("missing task comm")?;
                ensure!(
                    text.split_whitespace().next() == Some(tid.to_string().as_str()),
                    "task ID changed"
                );
                let scheduler = if scheduler {
                    let extra =
                        crate::scheduler::collect(&root.join(tid.to_string()), wait_accounting);
                    let after = procfs::parse_stat(&fs::read_to_string(
                        root.join(tid.to_string()).join("stat"),
                    )?)?;
                    ensure!(
                        after.start_ticks == stat.start_ticks,
                        "task replaced during scheduler reads"
                    );
                    Some(extra)
                } else {
                    None
                };
                Ok(ThreadSample {
                    scheduler,
                    tid,
                    start_ticks: stat.start_ticks,
                    name: name.into(),
                    elapsed_s,
                    cpu_ticks: stat.cpu_ticks,
                    cpu_delta_ticks: None,
                    born_since_previous: false,
                    interval_s: None,
                    cpu_percent: Metric::missing(
                        "% one core",
                        SOURCE,
                        "no matching prior task observation",
                    ),
                })
            })();
            match parsed {
                Ok(task) => snapshot.tasks.push(task),
                Err(e) => {
                    snapshot.unavailable_tasks += 1;
                    snapshot.error.get_or_insert_with(|| {
                        format!("task {tid} unavailable (exit, permission or parse failure): {e:#}")
                    });
                }
            }
        }
        Ok(())
    })();
    if let Err(e) = result {
        snapshot.error = Some(format!("task enumeration unavailable: {e:#}"));
    }
    snapshot.elapsed_s = Some(start.elapsed().as_secs_f64());
    snapshot.boot_ticks = boot_ticks();
    snapshot
}

fn boot_ticks() -> Option<u64> {
    let mut time: libc::timespec = unsafe { std::mem::zeroed() };
    if unsafe { libc::clock_gettime(libc::CLOCK_BOOTTIME, &mut time) } != 0 {
        return None;
    }
    let ticks = procfs::ticks_per_second().ok()?;
    Some(time.tv_sec as u64 * ticks + time.tv_nsec as u64 * ticks / 1_000_000_000)
}

/// Caller fences process identity and phase generation before supplying the prior sample.
pub fn derive(now: &mut ThreadSnapshot, previous: Option<&ThreadSnapshot>, ticks: u64) {
    let prior_snapshot = previous;
    let previous: BTreeMap<_, _> = previous
        .into_iter()
        .flat_map(|s| &s.tasks)
        .map(|t| ((t.tid, t.start_ticks), t))
        .collect();
    for task in &mut now.tasks {
        task.born_since_previous = false;
        let baseline = previous
            .get(&(task.tid, task.start_ticks))
            .map(|old| (old.cpu_ticks, old.elapsed_s))
            .or_else(|| {
                let old = prior_snapshot?;
                // Strictly later than the prior clock tick: same-tick births
                // are ambiguous. Never zero-baseline a merely missed older task.
                if task.start_ticks > old.boot_ticks? && task.start_ticks <= now.boot_ticks? {
                    task.born_since_previous = true;
                    Some((0, old.elapsed_s?))
                } else {
                    None
                }
            });
        let value = baseline.and_then(|(cpu, elapsed)| {
            let dt = task.elapsed_s - elapsed;
            let delta = task.cpu_ticks.checked_sub(cpu)?;
            (dt > 0.0 && ticks > 0).then_some((delta, dt))
        });
        task.cpu_delta_ticks = value.map(|(delta, _)| delta);
        task.interval_s = value.map(|(_, dt)| dt);
        task.cpu_percent = match value {
            Some((delta, dt)) => Metric::new(
                delta as f64 * 100.0 / ticks as f64 / dt,
                "% one core",
                SOURCE,
            ),
            None => Metric::missing(
                "% one core",
                SOURCE,
                "first task observation, TID reuse, phase boundary, missing observation or counter reset",
            ),
        };
    }
}

pub fn residual(now: &Sample, previous: Option<&Sample>, ticks: u64) -> Metric {
    let value = (|| {
        let old = previous?;
        let tasks = now.threads.as_ref()?;
        old.threads.as_ref()?;
        let process_delta = now
            .counters
            .get("cpu_ticks")?
            .value?
            .checked_sub(old.counters.get("cpu_ticks")?.value?)?;
        let attributed = tasks
            .tasks
            .iter()
            .filter_map(|t| t.cpu_delta_ticks)
            .try_fold(0u64, u64::checked_add)?;
        let delta = process_delta.checked_sub(attributed)?;
        let dt = now.elapsed_s - old.elapsed_s;
        (dt > 0.0 && ticks > 0).then_some(delta as f64 * 100.0 / ticks as f64 / dt)
    })();
    match value {
        Some(value) => Metric::new(
            value,
            "% one core",
            "process CPU delta minus observed task deltas",
        ),
        None => Metric::missing(
            "% one core",
            "process CPU delta minus observed task deltas",
            "no paired process/task snapshots, reset or negative residual from sampling skew",
        ),
    }
}

pub fn summarize(samples: &[Sample]) -> Vec<ThreadSummary> {
    let mut groups = BTreeMap::<_, (ThreadSummary, f64)>::new();
    for s in samples.iter().filter(|s| s.error.is_none()) {
        for t in s.threads.iter().flat_map(|snapshot| &snapshot.tasks) {
            let (row, integral) = groups
                .entry((s.label.clone(), s.phase.clone(), t.tid, t.start_ticks))
                .or_insert_with(|| {
                    (
                        ThreadSummary {
                            label: s.label.clone(),
                            phase: s.phase.clone(),
                            tid: t.tid,
                            start_ticks: t.start_ticks,
                            last_name: t.name.clone(),
                            observations: 0,
                            max_observed_cpu_ticks: 0,
                            born_during_capture: false,
                            covered_s: 0.0,
                            cpu_percent_one_core: None,
                        },
                        0.0,
                    )
                });
            row.last_name.clone_from(&t.name);
            row.observations += 1;
            row.born_during_capture |= t.born_since_previous;
            row.max_observed_cpu_ticks = row.max_observed_cpu_ticks.max(t.cpu_ticks);
            if let (Some(cpu), Some(dt)) = (t.cpu_percent.value, t.interval_s) {
                row.covered_s += dt;
                *integral += cpu * dt;
            }
        }
    }
    groups
        .into_values()
        .map(|(mut row, integral)| {
            row.cpu_percent_one_core = (row.covered_s > 0.0).then(|| integral / row.covered_s);
            row
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    fn task() -> ThreadSample {
        ThreadSample {
            tid: 7,
            start_ticks: 99,
            name: "worker".into(),
            elapsed_s: 1.0,
            scheduler: None,
            cpu_ticks: 10,
            cpu_delta_ticks: None,
            born_since_previous: false,
            interval_s: None,
            cpu_percent: Metric::missing("% one core", SOURCE, "first"),
        }
    }
    #[test]
    fn task_rates_use_identity_and_actual_intervals_and_never_bridge_gaps() {
        let old = ThreadSnapshot {
            tasks: vec![task()],
            ..Default::default()
        };
        let mut now = old.clone();
        now.tasks[0].elapsed_s = 3.0;
        now.tasks[0].cpu_ticks = 110;
        derive(&mut now, Some(&old), 100);
        assert_eq!(now.tasks[0].cpu_percent.value, Some(50.0));
        assert_eq!(now.tasks[0].interval_s, Some(2.0));
        now.tasks[0].start_ticks += 1;
        derive(&mut now, Some(&old), 100);
        assert!(now.tasks[0].cpu_percent.value.is_none());
        now.tasks[0].start_ticks -= 1;
        now.tasks[0].cpu_ticks = 1;
        derive(&mut now, Some(&old), 100);
        assert!(now.tasks[0].interval_s.is_none());
        now.tasks[0].cpu_ticks = 110;
        derive(&mut now, None, 100);
        assert!(now.tasks[0].cpu_percent.value.is_none());
        derive(&mut now, Some(&ThreadSnapshot::default()), 100);
        assert!(now.tasks[0].cpu_percent.value.is_none());
    }
    #[test]
    fn births_are_zero_based_only_when_proven_after_the_previous_snapshot() {
        let old = ThreadSnapshot {
            elapsed_s: Some(1.0),
            boot_ticks: Some(100),
            ..Default::default()
        };
        let mut now = ThreadSnapshot {
            tasks: vec![task()],
            elapsed_s: Some(3.0),
            boot_ticks: Some(300),
            ..Default::default()
        };
        now.tasks[0].elapsed_s = 3.0;
        for (birth, expected) in [(99, None), (100, None), (101, Some(5.0)), (301, None)] {
            now.tasks[0].start_ticks = birth;
            derive(&mut now, Some(&old), 100);
            assert_eq!(now.tasks[0].cpu_percent.value, expected);
            assert_eq!(now.tasks[0].born_since_previous, expected.is_some());
        }
        derive(&mut now, None, 100);
        assert!(!now.tasks[0].born_since_previous);
    }

    #[test]
    fn comm_parsing_and_weighted_summary_preserve_reused_task_identity() {
        let root = tempfile::tempdir().unwrap();
        fs::create_dir(root.path().join("7")).unwrap();
        let mut fields = vec!["0"; 22];
        fields[0] = "S";
        fields[11] = "10";
        fields[12] = "20";
        fields[19] = "99";
        fs::write(
            root.path().join("7/stat"),
            format!("7 (hot ) <&>) {}", fields.join(" ")),
        )
        .unwrap();
        let snapshot = collect_at(root.path(), Instant::now(), false);
        assert!(snapshot.error.is_none());
        assert_eq!(snapshot.tasks[0].name, "hot ) <&>");
        assert_eq!(snapshot.tasks[0].cpu_ticks, 30);
        let target = crate::model::Target {
            label: "fixture".into(),
            identity: procfs::identity(std::process::id()).unwrap(),
        };
        let mut a = crate::sampler::collect(
            &target,
            0,
            Instant::now(),
            "capture",
            false,
            crate::sampler::TaskDetail::None,
            &mut Default::default(),
        );
        a.threads = Some(snapshot);
        let t = &mut a.threads.as_mut().unwrap().tasks[0];
        t.cpu_percent = Metric::new(75.0, "% one core", SOURCE);
        t.interval_s = Some(1.0);
        let mut b = a.clone();
        let t = &mut b.threads.as_mut().unwrap().tasks[0];
        t.cpu_percent.value = Some(25.0);
        t.interval_s = Some(3.0);
        let mut reused = b.clone();
        reused.threads.as_mut().unwrap().tasks[0].start_ticks += 1;
        let rows = summarize(&[a, b, reused]);
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].covered_s, 4.0);
        assert_eq!(rows[0].cpu_percent_one_core, Some(37.5));
        assert_eq!(rows[0].observations, 2);
        assert_eq!(rows[1].cpu_percent_one_core, Some(25.0));
    }

    #[test]
    fn process_residual_exposes_exited_work_without_clamping_sampling_skew() {
        let target = crate::model::Target {
            label: "fixture".into(),
            identity: procfs::identity(std::process::id()).unwrap(),
        };
        let mut old = crate::sampler::collect(
            &target,
            0,
            Instant::now(),
            "capture",
            false,
            crate::sampler::TaskDetail::None,
            &mut Default::default(),
        );
        old.elapsed_s = 1.0;
        old.counters.get_mut("cpu_ticks").unwrap().value = Some(100);
        old.threads = Some(ThreadSnapshot::default());
        let mut now = old.clone();
        now.elapsed_s = 2.0;
        now.counters.get_mut("cpu_ticks").unwrap().value = Some(180);
        let mut t = task();
        t.cpu_delta_ticks = Some(30);
        now.threads.as_mut().unwrap().tasks.push(t);
        assert_eq!(residual(&now, Some(&old), 100).value, Some(50.0));
        now.threads.as_mut().unwrap().tasks[0].cpu_delta_ticks = Some(90);
        assert!(residual(&now, Some(&old), 100).value.is_none());
        assert!(residual(&now, None, 100).value.is_none());
    }

    #[test]
    fn missing_tasks_and_enumeration_limits_are_explicit() {
        let root = tempfile::tempdir().unwrap();
        assert!(
            collect_at(&root.path().join("absent"), Instant::now(), false)
                .error
                .is_some()
        );
        fs::create_dir(root.path().join("1")).unwrap();
        let sample = collect_at(root.path(), Instant::now(), false);
        assert_eq!(sample.unavailable_tasks, 1);
        assert!(sample.error.is_some());
        for tid in 2..=MAX_TASKS + 1 {
            fs::create_dir(root.path().join(tid.to_string())).unwrap();
        }
        let sample = collect_at(root.path(), Instant::now(), false);
        assert!(sample.tasks.is_empty());
        assert!(sample.error.unwrap().contains("limit exceeded"));
    }
}
