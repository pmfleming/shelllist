use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

pub const SCHEMA: u32 = 1;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Identity {
    pub pid: u32,
    pub start_ticks: u64,
    pub uid: u32,
    pub executable: String,
    pub executable_sha256: String,
    pub boot_id: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Target {
    pub label: String,
    pub identity: Identity,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Counter {
    pub value: Option<u64>,
    pub unit: String,
    pub source: String,
    pub reason: Option<String>,
}
impl Counter {
    pub fn new(value: u64, unit: &str, source: &str) -> Self {
        Self {
            value: Some(value),
            unit: unit.into(),
            source: source.into(),
            reason: None,
        }
    }
    pub fn missing(unit: &str, source: &str, reason: impl Into<String>) -> Self {
        Self {
            value: None,
            unit: unit.into(),
            source: source.into(),
            reason: Some(reason.into()),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Metric {
    pub value: Option<f64>,
    pub unit: String,
    pub source: String,
    pub reason: Option<String>,
}
impl Metric {
    pub fn new(value: f64, unit: &str, source: &str) -> Self {
        Self {
            value: Some(value),
            unit: unit.into(),
            source: source.into(),
            reason: None,
        }
    }
    pub fn missing(unit: &str, source: &str, reason: impl Into<String>) -> Self {
        Self {
            value: None,
            unit: unit.into(),
            source: source.into(),
            reason: Some(reason.into()),
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct GpuClient {
    pub device: String,
    pub driver: String,
    pub client_id: u64,
    pub engines_ns: BTreeMap<String, u64>,
    pub capacities: BTreeMap<String, u64>,
    pub memory_bytes: BTreeMap<String, u64>,
    pub busy_ns: BTreeMap<String, Counter>,
    pub utilization: BTreeMap<String, Metric>,
    pub interval_s: Option<f64>,
}
impl GpuClient {
    pub fn key(&self) -> String {
        format!("{}:{}:{}", self.driver, self.device, self.client_id)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Sample {
    pub sequence: u64,
    pub elapsed_s: f64,
    pub phase: String,
    /// Changes even when a short intermediate phase was missed by sampling.
    pub phase_sequence: u64,
    pub label: String,
    pub pid: u32,
    pub start_ticks: u64,
    pub interval_s: Option<f64>,
    pub counters: BTreeMap<String, Counter>,
    pub rates: BTreeMap<String, Metric>,
    pub gpu: Vec<GpuClient>,
    pub gpu_reason: Option<String>,
    pub error: Option<String>,
    pub collection_ms: f64,
    pub late_by_ms: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Event {
    pub elapsed_s: f64,
    pub trial: u32,
    pub phase: String,
    pub kind: String,
    pub data: serde_json::Value,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Manifest {
    pub schema_version: u32,
    pub run_id: String,
    pub started_unix_ms: u64,
    pub finished_unix_ms: Option<u64>,
    pub status: String,
    pub error: Option<String>,
    pub lens_version: String,
    pub lens_sha256: String,
    pub ticks_per_second: u64,
    pub targets: Vec<Target>,
    pub scenario: String,
    pub settings: serde_json::Value,
    pub context: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub hashes: BTreeMap<String, String>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ResourceSummary {
    pub label: String,
    pub phase: String,
    pub samples: usize,
    pub errors: usize,
    pub valid_cpu_seconds: f64,
    pub cpu_percent_one_core: Option<f64>,
    pub cpu_sampled_peak_percent: Option<f64>,
    pub rss_start_bytes: Option<u64>,
    pub rss_end_bytes: Option<u64>,
    pub rss_sampled_peak_bytes: Option<u64>,
    pub pss_sampled_peak_bytes: Option<u64>,
    pub io_read_observed_bytes: Option<f64>,
    pub io_write_observed_bytes: Option<f64>,
    pub io_read_covered_s: f64,
    pub io_write_covered_s: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Distribution {
    pub count: usize,
    pub median_ms: Option<f64>,
    pub p95_ms: Option<f64>,
    pub maximum_ms: Option<f64>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Summary {
    pub schema_version: u32,
    pub run_id: String,
    pub raw_sha256: BTreeMap<String, String>,
    pub status: String,
    pub resources: Vec<ResourceSummary>,
    pub attempted_trials: usize,
    pub successful_trials: usize,
    pub failed_trials: usize,
    pub acknowledgement: Distribution,
    pub qt_frame_callback: Distribution,
    pub gaps: BTreeMap<String, usize>,
}
