//! Optional task-level localization, not stack profiling or an additive CPU total.
use crate::{
    model::{Metric, Sample, ThreadSample, ThreadSnapshot, ThreadSummary},
    procfs,
};
use anyhow::{Context, Result, ensure};
use std::{collections::BTreeMap, fs, path::Path, time::Instant};

pub const MAX_TASKS: usize = 1024;
const SOURCE: &str = "proc/task/stat delta";

pub fn collect(pid: u32, start: Instant) -> ThreadSnapshot {
    collect_at(Path::new(&format!("/proc/{pid}/task")), start)
}

fn collect_at(root: &Path, start: Instant) -> ThreadSnapshot {
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
                Ok(ThreadSample {
                    tid,
                    start_ticks: stat.start_ticks,
                    name: name.into(),
                    elapsed_s,
                    cpu_ticks: stat.cpu_ticks,
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
    snapshot
}

/// Caller fences process identity and phase generation before supplying the prior sample.
pub fn derive(now: &mut ThreadSnapshot, previous: Option<&ThreadSnapshot>, ticks: u64) {
    let previous: BTreeMap<_, _> = previous
        .into_iter()
        .flat_map(|s| &s.tasks)
        .map(|t| ((t.tid, t.start_ticks), t))
        .collect();
    for task in &mut now.tasks {
        let value = previous.get(&(task.tid, task.start_ticks)).and_then(|old| {
            let dt = task.elapsed_s - old.elapsed_s;
            let delta = task.cpu_ticks.checked_sub(old.cpu_ticks)?;
            (dt > 0.0 && ticks > 0).then_some((delta as f64 * 100.0 / ticks as f64 / dt, dt))
        });
        task.interval_s = value.map(|(_, dt)| dt);
        task.cpu_percent = match value {
            Some((v, _)) => Metric::new(v, "% one core", SOURCE),
            None => Metric::missing(
                "% one core",
                SOURCE,
                "first task observation, TID reuse, phase boundary, missing observation or counter reset",
            ),
        };
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
                            covered_s: 0.0,
                            cpu_percent_one_core: None,
                        },
                        0.0,
                    )
                });
            row.last_name.clone_from(&t.name);
            row.observations += 1;
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
            cpu_ticks: 10,
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
        let snapshot = collect_at(root.path(), Instant::now());
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
            false,
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
    fn missing_tasks_and_enumeration_limits_are_explicit() {
        let root = tempfile::tempdir().unwrap();
        assert!(
            collect_at(&root.path().join("absent"), Instant::now())
                .error
                .is_some()
        );
        fs::create_dir(root.path().join("1")).unwrap();
        let sample = collect_at(root.path(), Instant::now());
        assert_eq!(sample.unavailable_tasks, 1);
        assert!(sample.error.is_some());
        for tid in 2..=MAX_TASKS + 1 {
            fs::create_dir(root.path().join(tid.to_string())).unwrap();
        }
        let sample = collect_at(root.path(), Instant::now());
        assert!(sample.tasks.is_empty());
        assert!(sample.error.unwrap().contains("limit exceeded"));
    }
}
