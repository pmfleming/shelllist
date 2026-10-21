use crate::{artifacts, model::*};
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
    Summary {
        schema_version: SCHEMA,
        run_id: manifest.run_id.clone(),
        raw_sha256: manifest.hashes.clone(),
        status: manifest.status.clone(),
        resources,
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

pub fn compare(baseline: &Path, candidate: &Path, output: &Path) -> Result<bool> {
    let (a, sa, ea) = artifacts::load(baseline)?;
    let (b, sb, eb) = artifacts::load(candidate)?;
    let left = artifacts::comparison_context(&a);
    let right = artifacts::comparison_context(&b);
    let mut reasons = Vec::new();
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
    for ar in &a_summary.resources {
        if ar.label != "ui-host" {
            continue;
        }
        if let Some(br) = b_summary
            .resources
            .iter()
            .find(|br| br.label == ar.label && br.phase == ar.phase)
        {
            for (name, av, bv) in [
                (
                    "cpu_percent",
                    ar.cpu_percent_one_core,
                    br.cpu_percent_one_core,
                ),
                (
                    "rss_peak_bytes",
                    ar.rss_sampled_peak_bytes.map(|v| v as f64),
                    br.rss_sampled_peak_bytes.map(|v| v as f64),
                ),
                (
                    "pss_peak_bytes",
                    ar.pss_sampled_peak_bytes.map(|v| v as f64),
                    br.pss_sampled_peak_bytes.map(|v| v as f64),
                ),
                (
                    "read_observed_bytes",
                    ar.io_read_observed_bytes,
                    br.io_read_observed_bytes,
                ),
                (
                    "write_observed_bytes",
                    ar.io_write_observed_bytes,
                    br.io_write_observed_bytes,
                ),
            ] {
                rows.push(delta(&format!("{} / {name}", ar.phase), av, bv));
            }
        }
    }
    let compatible = reasons.is_empty();
    let payload = json!({"schema_version":SCHEMA,"status":if compatible {"comparable_descriptive_only"} else {"incomparable"},"reasons":reasons,"baseline":a.run_id,"candidate":b.run_id,"deltas":if compatible {json!(rows)} else {json!(null)},"note":"No significance or budget verdict. Review coverage intervals; compare repeated alternating A/B runs. Operator context is a declaration, not verified display state."});
    ensure!(
        !output.exists(),
        "comparison output already exists; refusing overwrite"
    );
    std::fs::create_dir_all(output)?;
    artifacts::atomic_json(&output.join("comparison.json"), &payload)?;
    let mut html = page("Shelllist baseline comparison");
    html.push_str("<header><h1>Baseline comparison</h1><p>Descriptive evidence only; no automatic regression verdict.</p></header><section><pre>");
    html.push_str(&escape(&serde_json::to_string_pretty(&payload)?));
    html.push_str("</pre></section></main></body></html>");
    artifacts::atomic_write(&output.join("report.html"), html.as_bytes())?;
    Ok(compatible)
}
fn delta(name: &str, a: Option<f64>, b: Option<f64>) -> serde_json::Value {
    json!({"metric":name,"baseline":a,"candidate":b,"absolute_delta":a.zip(b).map(|(a,b)|b-a),"relative_percent":a.zip(b).filter(|(a,_)|a.abs()>1e-9).map(|(a,b)|(b-a)/a*100.0)})
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
