use crate::{
    artifacts,
    comparison::{self, delta},
    model::*,
    threads,
};
use anyhow::{Result, ensure};
use serde_json::json;
use std::{collections::BTreeMap, fmt::Write as _, path::Path};

pub fn distribution(mut values: Vec<f64>) -> Distribution {
    values.sort_by(f64::total_cmp);
    let n = values.len();
    Distribution {
        count: n,
        median_ms: if n == 0 {
            None
        } else {
            Some((values[(n - 1) / 2] + values[n / 2]) / 2.0)
        },
        p95_ms: (n >= 20).then(|| values[(0.95 * n as f64).ceil() as usize - 1]),
        maximum_ms: values.last().copied(),
    }
}

pub fn summarize(manifest: &Manifest, samples: &[Sample], events: &[Event]) -> Summary {
    let mut groups = BTreeMap::<(String, String), Vec<&Sample>>::new();
    let mut gaps = BTreeMap::<String, usize>::new();
    for s in samples {
        groups
            .entry((s.label.clone(), s.phase.clone()))
            .or_default()
            .push(s);
        for (id, c) in &s.counters {
            if let Some(reason) = &c.reason {
                *gaps
                    .entry(format!("{} / {id}: {reason}", s.label))
                    .or_default() += 1;
            }
        }
        for (id, m) in &s.rates {
            if let Some(reason) = &m.reason {
                *gaps
                    .entry(format!("{} / {id}: {reason}", s.label))
                    .or_default() += 1;
            }
        }
        for g in &s.gpu {
            for (engine, metric) in &g.utilization {
                if let Some(reason) = &metric.reason {
                    *gaps
                        .entry(format!(
                            "{} / GPU {} / {engine}: {reason}",
                            s.label,
                            g.key()
                        ))
                        .or_default() += 1;
                }
            }
        }
        if let Some(reason) = &s.gpu_reason {
            *gaps
                .entry(format!("{} / GPU: {reason}", s.label))
                .or_default() += 1;
        }
        if let Some(snapshot) = &s.threads {
            if let Some(reason) = &snapshot.error {
                *gaps
                    .entry(format!("{} / tasks: {reason}", s.label))
                    .or_default() += 1;
            }
            for task in &snapshot.tasks {
                if let Some(reason) = &task.cpu_percent.reason {
                    *gaps
                        .entry(format!("{} / task CPU: {reason}", s.label))
                        .or_default() += 1;
                }
            }
        }
        if let Some(reason) = &s.error {
            *gaps
                .entry(format!("{} / process: {reason}", s.label))
                .or_default() += 1;
        }
    }
    let resources = groups
        .into_iter()
        .map(|((label, phase), rows)| {
            let counter = |key: &str| {
                rows.iter()
                    .filter_map(|s| s.counters.get(key)?.value)
                    .collect::<Vec<_>>()
            };
            let rss = counter("rss_bytes");
            let pss = counter("pss_bytes");
            let integral = |key: &str| {
                let values: Vec<_> = rows
                    .iter()
                    .filter_map(|s| Some((s.rates.get(key)?.value?, s.interval_s?)))
                    .collect();
                let seconds = values.iter().map(|(_, s)| s).sum::<f64>();
                let total = values.iter().map(|(v, s)| v * s).sum::<f64>();
                ((!values.is_empty()).then_some(total), seconds)
            };
            let (cpu, cpu_seconds) = integral("cpu_percent");
            let (read, read_s) = integral("read_bytes_per_second");
            let (write, write_s) = integral("write_bytes_per_second");
            ResourceSummary {
                label,
                phase,
                samples: rows.len(),
                errors: rows.iter().filter(|s| s.error.is_some()).count(),
                valid_cpu_seconds: cpu_seconds,
                cpu_percent_one_core: cpu.map(|n| n / cpu_seconds),
                cpu_sampled_peak_percent: rows
                    .iter()
                    .filter_map(|s| s.rates.get("cpu_percent")?.value)
                    .max_by(f64::total_cmp),
                rss_start_bytes: rss.first().copied(),
                rss_end_bytes: rss.last().copied(),
                rss_sampled_peak_bytes: rss.iter().max().copied(),
                pss_sampled_peak_bytes: pss.iter().max().copied(),
                io_read_observed_bytes: read,
                io_write_observed_bytes: write,
                io_read_covered_s: read_s,
                io_write_covered_s: write_s,
            }
        })
        .collect();
    let attempted = events
        .iter()
        .filter(|e| e.kind == "trial_started" && e.phase == "warm-open")
        .count();
    let successful: Vec<_> = events
        .iter()
        .filter(|e| {
            e.kind == "trial_finished" && e.phase == "warm-open" && e.data["status"] == "ok"
        })
        .collect();
    let threads = threads::summarize(samples);
    let evidence_limits = evidence_limits(manifest, attempted, &threads);
    Summary {
        schema_version: SCHEMA,
        run_id: manifest.run_id.clone(),
        raw_sha256: manifest.hashes.clone(),
        status: manifest.status.clone(),
        resources,
        threads,
        evidence_limits,
        attempted_trials: attempted,
        successful_trials: successful.len(),
        failed_trials: attempted.saturating_sub(successful.len()),
        acknowledgement: distribution(
            successful
                .iter()
                .filter_map(|e| e.data["ack_ms"].as_f64())
                .collect(),
        ),
        qt_frame_callback: distribution(
            successful
                .iter()
                .filter_map(|e| e.data["qt_frame_callback_ms"].as_f64())
                .collect(),
        ),
        gaps,
    }
}

fn evidence_limits(
    manifest: &Manifest,
    attempted: usize,
    threads: &[ThreadSummary],
) -> Vec<String> {
    let mut limits = vec![
        "Measurements describe deployed executables/config, not the current source checkout. A source commit is not proof of deployment.".into(),
        "No operation-level benchmark evidence: search ranking, catalog preparation, history projection and watcher registration require separate controlled probes. Idle samples cannot establish their speedups.".into(),
        "No stack profiling or causal attribution. Related daemons may serve other clients; threads are already included in process CPU.".into(),
    ];
    if attempted == 0 {
        limits.push("No responsiveness trials measured. Resource capture is not evidence of input-to-visible latency or improved responsiveness.".into());
    }
    if manifest.settings["include_threads"] != true {
        limits.push("Thread CPU localization was not requested. Use --include-threads at main sampling cadence for a separate diagnostic capture; this adds observer cost.".into());
    } else {
        limits.push("Thread localization is a bounded snapshot (1024 tasks/process). Short-lived tasks may be missed; names can change or repeat, and task CPU is not summed into process totals. At least two same-phase observations of the same task identity are needed. See the manifest for cadence.".into());
        let unpaired = threads
            .iter()
            .filter(|t| t.phase != "initial-settle" && t.cpu_percent_one_core.is_none())
            .count();
        if unpaired > 0 {
            limits.push(format!("{unpaired} task identity/phase entries lack a valid CPU interval. A quiet-looking thread rate table does not account for all process CPU. Inspect unpaired task lifetime counters; consider a shorter --interval-ms in a separate diagnostic run."));
        }
    }
    limits
}

pub fn escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}
fn number(v: Option<f64>) -> String {
    v.map(|n| format!("{n:.3}"))
        .unwrap_or_else(|| "unavailable".into())
}
fn write_rate(row: &ResourceSummary) -> Option<f64> {
    (row.io_write_covered_s > 0.0)
        .then(|| {
            row.io_write_observed_bytes
                .map(|n| n / row.io_write_covered_s)
        })
        .flatten()
}
fn mib(v: Option<u64>) -> String {
    number(v.map(|n| n as f64 / 1048576.0))
}
fn page(title: &str) -> String {
    format!(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>{}</title><style>body{{font:16px/1.6 system-ui,sans-serif;color:#18313e;background:#f0f5f7;margin:0}}main{{max-width:1200px;margin:auto;padding:32px}}section,header{{background:white;padding:24px;margin-bottom:20px;border-radius:8px}}h1,h2{{line-height:1.2}}table{{border-collapse:collapse;font-size:14px;width:100%}}td,th{{padding:9px;text-align:left;border-bottom:1px solid #d8e4ea;vertical-align:top}}.table{{overflow:auto}}.note{{color:#506674}}pre{{white-space:pre-wrap;overflow-wrap:anywhere;background:#f1f5f7;padding:16px}}svg{{width:100%;height:180px;background:#f4f8fa}}a{{color:#096e72}}@media print{{body{{background:white}}main{{padding:0}}}}</style></head><body><main>",
        escape(title)
    )
}

fn chart(samples: &[Sample], label: &str, key: &str, divisor: f64) -> String {
    let series: Vec<_> = samples.iter().filter(|s| s.label == label).collect();
    let points: Vec<_> = series
        .iter()
        .enumerate()
        .filter_map(|(i, s)| {
            let v = s
                .rates
                .get(key)
                .and_then(|m| m.value)
                .or_else(|| s.counters.get(key).and_then(|c| c.value).map(|n| n as f64))?;
            Some((i, s.elapsed_s, v / divisor))
        })
        .collect();
    if points.is_empty() {
        return "<p>Timeline unavailable.</p>".into();
    }
    let xmax = samples
        .last()
        .map(|s| s.elapsed_s)
        .unwrap_or(1.0)
        .max(0.001);
    let ymax = points
        .iter()
        .map(|(_, _, y)| *y)
        .fold(0.0, f64::max)
        .max(0.001);
    let stride = (points.len() / 1000).max(1);
    let mut svg = format!(
        "<p class=\"note\">{} / {} — observed points, 0–{xmax:.2} s, 0–{ymax:.3}; stride {stride}. Gaps are not interpolated.</p><svg viewBox=\"0 0 1000 180\" role=\"img\" aria-label=\"{}\">",
        escape(label),
        escape(key),
        escape(key)
    );
    for (_, x, y) in points.iter().step_by(stride) {
        let _ = write!(
            svg,
            "<circle cx=\"{:.2}\" cy=\"{:.2}\" r=\"2\" fill=\"#087b7e\"/>",
            10.0 + x / xmax * 980.0,
            170.0 - y / ymax * 155.0
        );
    }
    svg.push_str("</svg>");
    svg
}

pub fn write(
    path: &Path,
    manifest: &Manifest,
    summary: &Summary,
    samples: &[Sample],
    events: &[Event],
) -> Result<()> {
    artifacts::atomic_json(&path.join("summary.json"), summary)?;
    let mut html = page("Shelllist performance capture");
    let _ = write!(
        html,
        "<header><h1>Shelllist performance lens</h1><p>Run {} · {} · <strong>{}</strong></p><p>{}</p><p>No JavaScript. Process-scoped observations, not physical input-to-photon or GPU frame timings. No budget verdicts are inferred.</p></header>",
        escape(&manifest.run_id),
        escape(&manifest.scenario),
        escape(&manifest.status),
        escape(manifest.error.as_deref().unwrap_or(""))
    );
    html.push_str("<section><h2>Triage and evidence limits</h2><ul>");
    for limit in &summary.evidence_limits {
        let _ = write!(html, "<li>{}</li>", escape(limit));
    }
    html.push_str("</ul><h3>Highest observed CPU by scope / phase</h3><p>Localization only, not proof of a bottleneck. Initial settling is excluded here; all phases remain below.</p><table><tr><th>Scope / phase</th><th>% one core</th><th>CPU covered s</th><th>Write bytes/s</th><th>Write covered s</th></tr>");
    let mut hotspots: Vec<_> = summary
        .resources
        .iter()
        .filter(|r| r.phase != "initial-settle" && r.cpu_percent_one_core.is_some())
        .collect();
    hotspots.sort_by(|a, b| {
        b.cpu_percent_one_core
            .unwrap()
            .total_cmp(&a.cpu_percent_one_core.unwrap())
    });
    for r in hotspots.into_iter().take(10) {
        let _ = write!(
            html,
            "<tr><td>{} / {}</td><td>{}</td><td>{:.3}</td><td>{}</td><td>{:.3}</td></tr>",
            escape(&r.label),
            escape(&r.phase),
            number(r.cpu_percent_one_core),
            r.valid_cpu_seconds,
            number(write_rate(r)),
            r.io_write_covered_s
        );
    }
    html.push_str("</table><h3>Highest observed disk-write rate</h3><p>Ranked independently of CPU. Process storage accounting, not durable writes or physical device throughput; rates use only covered intervals.</p><table><tr><th>Scope / phase</th><th>Write bytes/s</th><th>Observed write bytes</th><th>Covered seconds</th></tr>");
    let mut writers: Vec<_> = summary
        .resources
        .iter()
        .filter(|r| r.phase != "initial-settle" && write_rate(r).is_some())
        .collect();
    writers.sort_by(|a, b| write_rate(b).unwrap().total_cmp(&write_rate(a).unwrap()));
    for r in writers.into_iter().take(10) {
        let _ = write!(
            html,
            "<tr><td>{} / {}</td><td>{}</td><td>{}</td><td>{:.3}</td></tr>",
            escape(&r.label),
            escape(&r.phase),
            number(write_rate(r)),
            number(r.io_write_observed_bytes),
            r.io_write_covered_s
        );
    }
    html.push_str("</table></section>");
    if summary
        .resources
        .iter()
        .any(|r| r.label == "lens-observer" && r.cpu_percent_one_core.is_some_and(|v| v > 1.0))
    {
        html.push_str("<section><h2>Observer overhead warning</h2><p>The lens exceeded the provisional 1%-of-one-core overhead goal in at least one phase. Use fewer process scopes or increase <code>--detail-ms</code> (expensive PSS/GPU reads) and <code>--interval-ms</code>. This is not an application regression. Review covered duration and tick quantization.</p></section>");
    }
    html.push_str("<section><h2>Responsiveness</h2><p>Direct PID-targeted IPC acknowledgement includes helper launch. Qt frame-swap callback is not compositor presentation. Warm content zero means already loaded. p95 is descriptive; hidden below 20 successful trials. Warmup is excluded. No p99 or population-tail guarantee.</p>");
    let _ = write!(
        html,
        "<p>Attempted: {} · Successful: {} · Failed/unfinished: {}</p><div class=\"table\"><table><tr><th>Metric</th><th>n</th><th>Median ms</th><th>p95 ms</th><th>Max ms</th></tr>",
        summary.attempted_trials, summary.successful_trials, summary.failed_trials
    );
    for (name, d) in [
        ("Command acknowledgement", &summary.acknowledgement),
        ("Open → Qt callback", &summary.qt_frame_callback),
    ] {
        let _ = write!(
            html,
            "<tr><td>{name}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>",
            d.count,
            number(d.median_ms),
            number(d.p95_ms),
            number(d.maximum_ms)
        );
    }
    html.push_str(
        "</table></div><details><summary>Trial outcomes (including warmup and failures)</summary>",
    );
    for e in events.iter().filter(|e| e.kind == "trial_finished") {
        let _ = write!(
            html,
            "<pre>{}</pre>",
            escape(&serde_json::to_string_pretty(e)?)
        );
    }
    html.push_str("</details></section><section><h2>CPU</h2><p>100% is one core. Averages are weighted by valid observed intervals; threads are already included. Lens observer cost is separate; short-lived IPC helper CPU is not included.</p><div class=\"table\"><table><tr><th>Scope / phase</th><th>Average %</th><th>Sampled peak %</th><th>Covered seconds</th><th>Samples / errors</th></tr>");
    for r in &summary.resources {
        let _ = write!(
            html,
            "<tr><td>{} / {}</td><td>{}</td><td>{}</td><td>{:.3}</td><td>{} / {}</td></tr>",
            escape(&r.label),
            escape(&r.phase),
            number(r.cpu_percent_one_core),
            number(r.cpu_sampled_peak_percent),
            r.valid_cpu_seconds,
            r.samples,
            r.errors
        );
    }
    html.push_str("</table></div>");
    for t in &manifest.targets {
        html.push_str(&chart(samples, &t.label, "cpu_percent", 1.0));
    }
    html.push_str("</section><section><h2>Thread CPU localization</h2><p>% of one core at the manifest's task cadence, weighted by each task's valid intervals. TID + start ticks fence reuse; phase boundaries and missing observations break rates. Last observed names are diagnostic labels, not stable identities or function names. Do not add these to process CPU or sum task percentages covering different times. Showing the top 20 scope/phase/task entries outside initial settling; all observations and unknowns remain in JSON.</p>");
    let mut tasks: Vec<_> = summary
        .threads
        .iter()
        .filter(|t| t.phase != "initial-settle" && t.cpu_percent_one_core.is_some())
        .collect();
    tasks.sort_by(|a, b| {
        b.cpu_percent_one_core
            .unwrap()
            .total_cmp(&a.cpu_percent_one_core.unwrap())
    });
    if tasks.is_empty() {
        html.push_str("<p>No valid thread CPU intervals: collection was disabled, denied, interrupted or too short for two same-phase task samples. See raw task errors and evidence limits.</p>");
    } else {
        html.push_str("<table><tr><th>Scope / phase</th><th>TID / start ticks</th><th>Last name</th><th>% one core</th><th>Covered seconds</th></tr>");
        for t in tasks.into_iter().take(20) {
            let _ = write!(
                html,
                "<tr><td>{} / {}</td><td>{} / {}</td><td>{}</td><td>{}</td><td>{:.3}</td></tr>",
                escape(&t.label),
                escape(&t.phase),
                t.tid,
                t.start_ticks,
                escape(&t.last_name),
                number(t.cpu_percent_one_core),
                t.covered_s
            );
        }
        html.push_str("</table>");
    }
    let mut unpaired: Vec<_> = summary
        .threads
        .iter()
        .filter(|t| t.phase != "initial-settle" && t.cpu_percent_one_core.is_none())
        .collect();
    if !unpaired.is_empty() {
        unpaired.sort_by_key(|t| std::cmp::Reverse(t.max_observed_cpu_ticks));
        html.push_str("<h3>Tasks without a valid CPU interval</h3><p>These tasks must not be mistaken for idle threads. Showing up to 20, ranked by maximum observed lifetime CPU ticks. This is CPU since task birth at the snapshot, NOT CPU spent during capture and NOT a rate. Churn, phase boundaries and missing observations can prevent paired samples. No names or distinct identities are merged.</p><table><tr><th>Scope / phase</th><th>TID / start ticks</th><th>Last name</th><th>Lifetime CPU ticks</th><th>Observations</th></tr>");
        for t in unpaired.into_iter().take(20) {
            let _ = write!(
                html,
                "<tr><td>{} / {}</td><td>{} / {}</td><td>{}</td><td>{}</td><td>{}</td></tr>",
                escape(&t.label),
                escape(&t.phase),
                t.tid,
                t.start_ticks,
                escape(&t.last_name),
                t.max_observed_cpu_ticks,
                t.observations
            );
        }
        html.push_str("</table>");
    }
    html.push_str("</section><section><h2>Memory</h2><p>MiB. Peaks are sampled, not allocator peaks; VmHWM in raw data is process-lifetime. RSS sums are not unique physical memory. Start/end below are first/last available observations, not proof of coverage at the exact phase boundary.</p><div class=\"table\"><table><tr><th>Scope / phase</th><th>RSS first</th><th>RSS last</th><th>RSS peak</th><th>PSS peak</th></tr>");
    for r in &summary.resources {
        let _ = write!(
            html,
            "<tr><td>{} / {}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>",
            escape(&r.label),
            escape(&r.phase),
            mib(r.rss_start_bytes),
            mib(r.rss_end_bytes),
            mib(r.rss_sampled_peak_bytes),
            mib(r.pss_sampled_peak_bytes)
        );
    }
    html.push_str("</table></div>");
    for t in &manifest.targets {
        html.push_str(&chart(samples, &t.label, "rss_bytes", 1048576.0));
    }
    html.push_str("</section><section><h2>I/O</h2><p>Storage-accounted observed byte deltas over valid intervals only. Gaps and phase boundaries are excluded. Not syscall character traffic, network usage, durable writes or disk latency. Raw rchar/wchar and fault counters remain separate.</p><div class=\"table\"><table><tr><th>Scope / phase</th><th>Read bytes</th><th>Read covered s</th><th>Write bytes</th><th>Write covered s</th></tr>");
    for r in &summary.resources {
        let _ = write!(
            html,
            "<tr><td>{} / {}</td><td>{}</td><td>{:.3}</td><td>{}</td><td>{:.3}</td></tr>",
            escape(&r.label),
            escape(&r.phase),
            number(r.io_read_observed_bytes),
            r.io_read_covered_s,
            number(r.io_write_observed_bytes),
            r.io_write_covered_s
        );
    }
    html.push_str("</table></div>");
    for key in ["read_bytes_per_second", "write_bytes_per_second"] {
        html.push_str(&chart(samples, "ui-host", key, 1.0));
    }
    html.push_str("</section><section><h2>GPU</h2><p>DRM clients are deduplicated across descriptors/processes in each sampling batch. A shared client is assigned to the first observed scope, not counted twice. Engine percentages are per engine capacity (ABI default 1); no aggregate GPU percentage. Memory region fields may overlap each other and RSS. GPU/compositor frame times are unmeasured.</p><div class=\"table\"><table><tr><th>Scope / client / engine</th><th>Observed intervals</th><th>Time-weighted %</th><th>Peak %</th></tr>");
    let mut engines = BTreeMap::<String, Vec<(f64, f64)>>::new();
    let mut memory = BTreeMap::new();
    for s in samples {
        for g in &s.gpu {
            for (engine, v) in &g.utilization {
                if let (Some(v), Some(dt)) = (v.value, g.interval_s) {
                    engines
                        .entry(format!("{} / {} / {engine}", s.label, g.key()))
                        .or_default()
                        .push((v, dt));
                }
            }
            for (field, value) in &g.memory_bytes {
                memory.insert(format!("{} / {} / {field}", s.label, g.key()), *value);
            }
        }
    }
    for (name, values) in &engines {
        let duration: f64 = values.iter().map(|(_, t)| t).sum();
        let avg = values.iter().map(|(v, t)| v * t).sum::<f64>() / duration;
        let peak = values.iter().map(|(v, _)| *v).max_by(f64::total_cmp);
        let _ = write!(
            html,
            "<tr><td>{}</td><td>{}</td><td>{avg:.3}</td><td>{}</td></tr>",
            escape(name),
            values.len(),
            number(peak)
        );
    }
    html.push_str("</table></div>");
    if engines.is_empty() {
        html.push_str("<p>GPU utilization unavailable: no valid supported engine intervals. See capability gaps below.</p>");
    }
    html.push_str(
        "<details><summary>Last observed GPU memory fields (bytes; not a total)</summary><pre>",
    );
    html.push_str(&escape(&serde_json::to_string_pretty(&memory)?));
    html.push_str(
        "</pre></details></section><section><h2>Coverage, boundaries and provenance</h2><ul>",
    );
    for warning in &manifest.warnings {
        let _ = write!(html, "<li>{}</li>", escape(warning));
    }
    html.push_str("</ul><details open><summary>Missing observations and reasons</summary><pre>");
    html.push_str(&escape(&serde_json::to_string_pretty(&summary.gaps)?));
    html.push_str("</pre></details><details><summary>Manifest</summary><pre>");
    html.push_str(&escape(&serde_json::to_string_pretty(manifest)?));
    html.push_str("</pre></details><p><a href=\"manifest.json\">Manifest</a> · <a href=\"samples.jsonl\">Raw samples</a> · <a href=\"events.jsonl\">Raw events</a> · <a href=\"summary.json\">Summary</a> · <a href=\"samples.csv\">CSV</a></p></section></main></body></html>\n");
    artifacts::atomic_write(&path.join("report.html"), html.as_bytes())?;
    let mut csv = String::from("elapsed_s,phase,label,pid,metric,value,unit,source,reason\n");
    for s in samples {
        for (key, value, unit, source, reason) in s
            .counters
            .iter()
            .map(|(k, c)| {
                (
                    k,
                    c.value.map(|v| v.to_string()),
                    &c.unit,
                    &c.source,
                    &c.reason,
                )
            })
            .chain(s.rates.iter().map(|(k, c)| {
                (
                    k,
                    c.value.map(|v| v.to_string()),
                    &c.unit,
                    &c.source,
                    &c.reason,
                )
            }))
        {
            let row = [
                s.elapsed_s.to_string(),
                s.phase.clone(),
                s.label.clone(),
                s.pid.to_string(),
                key.clone(),
                value.unwrap_or_default(),
                unit.clone(),
                source.clone(),
                reason.clone().unwrap_or_default(),
            ];
            csv.push_str(
                &row.iter()
                    .map(|v| csv_cell(v))
                    .collect::<Vec<_>>()
                    .join(","),
            );
            csv.push('\n');
        }
    }
    artifacts::atomic_write(&path.join("samples.csv"), csv.as_bytes())?;
    Ok(())
}

fn csv_cell(value: &str) -> String {
    // Prevent spreadsheet formula injection in user-defined labels/context.
    let prefix = if value.starts_with(['=', '+', '-', '@', '\t', '\r']) {
        "'"
    } else {
        ""
    };
    format!("\"{prefix}{}\"", value.replace('"', "\"\""))
}

pub fn compare(
    baseline: &Path,
    candidate: &Path,
    output: &Path,
    changed_scopes: &[String],
) -> Result<bool> {
    let (a, sa, ea) = artifacts::load(baseline)?;
    let (b, sb, eb) = artifacts::load(candidate)?;
    let left = artifacts::comparison_context(&a, changed_scopes);
    let right = artifacts::comparison_context(&b, changed_scopes);
    let mut reasons = Vec::new();
    let ar = comparison::targets(&a);
    let br = comparison::targets(&b);
    for scope in changed_scopes {
        if !ar.contains_key(scope.as_str()) || !br.contains_key(scope.as_str()) {
            reasons.push(format!(
                "declared changed scope absent from one or both runs: {scope}"
            ));
        }
    }
    for key in left
        .keys()
        .chain(right.keys())
        .collect::<std::collections::BTreeSet<_>>()
    {
        if left.get(key) != right.get(key) {
            reasons.push(format!("context mismatch: {key}"));
        }
    }
    if a.context
        .get("operator_conditions")
        .is_none_or(|s| s.trim().is_empty())
        || b.context
            .get("operator_conditions")
            .is_none_or(|s| s.trim().is_empty())
    {
        reasons.push("missing operator --context declaration (display/scale/Hz/backend/power/workload must be matched)".into());
    }
    if a.context.get("machine_id").is_none_or(|v| v.is_empty())
        || b.context.get("machine_id").is_none_or(|v| v.is_empty())
    {
        reasons.push("machine identity unavailable".into());
    }
    if a.settings["config_identity"].is_null() || b.settings["config_identity"].is_null() {
        reasons.push("deployed QML config identity missing; supply --config-path for captures without an explicit process --path".into());
    }
    if a.status != "complete" || b.status != "complete" {
        reasons.push("one or both runs incomplete".into());
    }
    let a_summary = summarize(&a, &sa, &ea);
    let b_summary = summarize(&b, &sb, &eb);
    let mut rows = Vec::new();
    for (key, av, bv) in [
        (
            "ack_median_ms",
            a_summary.acknowledgement.median_ms,
            b_summary.acknowledgement.median_ms,
        ),
        (
            "qt_callback_median_ms",
            a_summary.qt_frame_callback.median_ms,
            b_summary.qt_frame_callback.median_ms,
        ),
    ] {
        rows.push(delta(key, av, bv));
    }
    let scopes = comparison::scopes(&a, &b, &a_summary, &b_summary);
    rows.extend(scopes.deltas);
    let observer_changed = a.lens_sha256 != b.lens_sha256;
    let qml_changed = a.settings["config_identity"] != b.settings["config_identity"];
    let mut warnings = vec!["Related daemon activity is not exclusively Shelllist-caused. No operation-level or deployment improvement follows from source changes alone.".to_string()];
    if observer_changed {
        warnings.push("Observer executable changed: conditional evidence only. Collector equivalence is not verified; observer CPU deltas and target deltas are not an isolated application A/B result.".into());
    }
    if !qml_changed
        && scopes
            .provenance
            .iter()
            .filter(|p| p["scope"] != "lens-observer")
            .all(|p| p["executable_hashes_changed"] == false)
    {
        warnings.push("No deployed target executable/config identity change observed. This comparison cannot demonstrate that checkout fixes were deployed; mutable config imports are not fully fingerprinted.".into());
    }
    let compatible = reasons.is_empty();
    let status = if !compatible {
        "incomparable"
    } else if observer_changed {
        "conditional_descriptive_only"
    } else {
        "comparable_descriptive_only"
    };
    let payload = json!({
        "schema_version":SCHEMA, "status":status, "reasons":reasons, "warnings":warnings,
        "baseline":a.run_id, "candidate":b.run_id, "declared_changed_scopes":changed_scopes,
        "observer_changed":observer_changed, "baseline_lens_sha256":a.lens_sha256, "candidate_lens_sha256":b.lens_sha256,
        "deployed_qml_changed":qml_changed, "baseline_config":a.settings["config_identity"], "candidate_config":b.settings["config_identity"],
        "scope_provenance":scopes.provenance, "unpaired_scopes":scopes.unpaired,
        "resource_coverage":{"baseline":a_summary.resources,"candidate":b_summary.resources},
        "deltas":if compatible {json!(rows)} else {json!(null)},
        "note":"No significance or budget verdict. Review coverage intervals; compare repeated alternating A/B runs. Operator context is a declaration, not verified display state. Missing metrics are null, never zero. Thread names/TIDs are not paired across runs."
    });
    ensure!(
        !output.exists(),
        "comparison output already exists; refusing overwrite"
    );
    std::fs::create_dir_all(output)?;
    artifacts::atomic_json(&output.join("comparison.json"), &payload)?;
    let mut html = page("Shelllist baseline comparison");
    let _ = write!(
        html,
        "<header><h1>Baseline comparison</h1><p><strong>{}</strong></p><p>Descriptive evidence only; no automatic regression verdict.</p></header><section><h2>Compatibility and evidence limits</h2><ul>",
        escape(status)
    );
    for message in payload["reasons"]
        .as_array()
        .unwrap()
        .iter()
        .chain(payload["warnings"].as_array().unwrap())
    {
        let _ = write!(html, "<li>{}</li>", escape(message.as_str().unwrap()));
    }
    let _ = write!(
        html,
        "</ul><p>Unpaired scope roles: {}. Ambiguous members are not matched by PID or silently summed. See full provenance below; use unique explicit labels to compare them.</p></section>",
        payload["unpaired_scopes"].as_array().unwrap().len()
    );
    if let Some(rows) = payload["deltas"].as_array() {
        html.push_str("<section><h2>Scoped deltas</h2><p>Negative is not automatically better. CPU/I/O covered seconds must be reviewed; memory peaks are sampled, not exact phase coverage. Missing observations are unavailable, never zero.</p><div class=\"table\"><table><tr><th>Metric</th><th>Baseline</th><th>Candidate</th><th>Delta</th><th>Relative %</th><th>CPU/I/O covered s (baseline / candidate)</th></tr>");
        for row in rows {
            let coverage = |key: &str| {
                row[key]
                    .as_f64()
                    .map(|v| format!("{v:.3}"))
                    .unwrap_or_else(|| "n/a".into())
            };
            let _ = write!(
                html,
                "<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td><td>{}</td><td>{} / {}</td></tr>",
                escape(row["metric"].as_str().unwrap()),
                number(row["baseline"].as_f64()),
                number(row["candidate"].as_f64()),
                number(row["absolute_delta"].as_f64()),
                number(row["relative_percent"].as_f64()),
                coverage("baseline_covered_s"),
                coverage("candidate_covered_s")
            );
        }
        html.push_str("</table></div></section>");
    }
    html.push_str("<section><details><summary>Full comparison, coverage and deployed provenance</summary><pre>");
    html.push_str(&escape(&serde_json::to_string_pretty(&payload)?));
    html.push_str("</pre></details></section></main></body></html>");
    artifacts::atomic_write(&output.join("report.html"), html.as_bytes())?;
    Ok(compatible)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn percentiles_and_escape() {
        let d = distribution(vec![4.0, 1.0, 2.0, 3.0]);
        assert_eq!(d.median_ms, Some(2.5));
        assert!(d.p95_ms.is_none());
        assert_eq!(
            distribution((1..=100).map(f64::from).collect()).p95_ms,
            Some(95.0)
        );
        assert!(distribution(vec![]).median_ms.is_none());
        assert_eq!(escape("<script>'&\""), "&lt;script&gt;&#39;&amp;&quot;");
        assert_eq!(csv_cell("=command"), "\"'=command\"");
    }
}
