//! Offline projection of existing raw rates; no extra sampling or inferred work.
use crate::model::{RateSummary, Sample};
use std::collections::BTreeMap;

pub fn summarize(samples: &[Sample]) -> Vec<RateSummary> {
    let mut counts = BTreeMap::new();
    let mut groups = BTreeMap::new();
    for sample in samples {
        *counts.entry((&sample.label, &sample.phase)).or_insert(0) += 1;
        for (metric, rate) in &sample.rates {
            // Keep provenance changes separate instead of averaging incompatible units.
            let key = (
                &sample.label,
                &sample.phase,
                metric,
                &rate.unit,
                &rate.source,
            );
            let (row, integral) = groups.entry(key).or_insert_with(|| {
                (
                    RateSummary {
                        label: sample.label.clone(),
                        phase: sample.phase.clone(),
                        metric: metric.clone(),
                        unit: rate.unit.clone(),
                        source: rate.source.clone(),
                        ..Default::default()
                    },
                    0.0,
                )
            });
            if let (Some(value), Some(dt)) = (rate.value, sample.interval_s)
                && sample.error.is_none()
                && value.is_finite()
                && dt.is_finite()
                && dt > 0.0
            {
                row.valid_intervals += 1;
                row.covered_s += dt;
                *integral += value * dt;
                row.sampled_peak = Some(row.sampled_peak.map_or(value, |peak| peak.max(value)));
            }
        }
    }
    groups
        .into_values()
        .map(|(mut row, integral)| {
            row.unavailable_observations = counts[&(&row.label, &row.phase)] - row.valid_intervals;
            if row.covered_s > 0.0 {
                row.average = Some(integral / row.covered_s);
            }
            row
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Metric;

    fn sample(label: &str, phase: &str, dt: Option<f64>, value: Option<f64>) -> Sample {
        let mut row: Sample = serde_json::from_value(serde_json::json!({
            "sequence":0,"elapsed_s":1.0,"phase":phase,"phase_sequence":1,
            "label":label,"pid":1,"start_ticks":1,"interval_s":dt,
            "counters":{},"rates":{},"gpu":[],"gpu_reason":null,
            "error":null,"collection_ms":0.0,"late_by_ms":0.0
        }))
        .unwrap();
        row.rates.insert(
            "rchar_per_second".into(),
            value.map_or_else(
                || Metric::missing("bytes/s", "proc delta: rchar", "unavailable"),
                |v| Metric::new(v, "bytes/s", "proc delta: rchar"),
            ),
        );
        row
    }

    #[test]
    fn weights_intervals_and_keeps_missing_zero_phase_and_scope_distinct() {
        let mut absent = sample("ui-host", "capture", Some(2.0), None);
        absent.rates.clear();
        let rows = vec![
            sample("ui-host", "capture", Some(1.0), Some(100.0)),
            sample("ui-host", "capture", Some(3.0), Some(0.0)),
            sample("ui-host", "capture", Some(2.0), None),
            sample("ui-host", "capture", None, Some(999.0)),
            absent,
            sample("ui-host", "initial-settle", Some(1.0), Some(999.0)),
            sample("lens-observer", "capture", Some(1.0), Some(8.0)),
        ];
        let summaries = summarize(&rows);
        let row = summaries
            .iter()
            .find(|r| r.label == "ui-host" && r.phase == "capture")
            .unwrap();
        assert_eq!(row.average, Some(25.0));
        assert_eq!(row.sampled_peak, Some(100.0));
        assert_eq!(row.covered_s, 4.0);
        assert_eq!(row.valid_intervals, 2);
        assert_eq!(row.unavailable_observations, 3);
        assert_eq!(summaries.len(), 3);
    }

    #[test]
    fn unavailable_is_not_zero_and_provenance_is_not_merged() {
        let mut denied = sample("ui-host", "capture", Some(1.0), Some(10.0));
        denied.error = Some("identity lost".into());
        let rows = [sample("ui-host", "capture", Some(1.0), None), denied];
        let summary = summarize(&rows).remove(0);
        assert_eq!(summary.average, None);
        assert_eq!(summary.sampled_peak, None);
        assert_eq!(summary.covered_s, 0.0);
        assert_eq!(summary.unavailable_observations, 2);
        let a = sample("ui-host", "capture", Some(1.0), Some(10.0));
        let mut b = a.clone();
        b.rates.get_mut("rchar_per_second").unwrap().unit = "different unit".into();
        let mut c = a.clone();
        c.rates.get_mut("rchar_per_second").unwrap().source = "different source".into();
        let summaries = summarize(&[a, b, c]);
        assert_eq!(summaries.len(), 3);
        assert!(
            summaries
                .iter()
                .all(|r| r.covered_s == 1.0 && r.unavailable_observations == 2)
        );
        assert!(summarize(&[]).is_empty());
    }
}
