//! Real Linux process and CLI tests. No live desktop or user service is touched.
use serde_json::Value;
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    time::{Duration, Instant},
};
use tempfile::TempDir;

#[path = "review_cases/mod.rs"]
mod review_cases;

const BIN: &str = env!("CARGO_BIN_EXE_shelllist-perf");
fn json(path: &Path) -> Value {
    serde_json::from_slice(&fs::read(path).unwrap()).unwrap()
}

struct Load {
    child: Child,
    dir: TempDir,
}
impl Load {
    fn start() -> Self {
        Self::with_churn(false)
    }
    fn with_churn(churn: bool) -> Self {
        let dir = tempfile::tempdir().unwrap();
        let child = Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "synthetic_load", "--ignored", "--nocapture"])
            .env("PERF_TEST_DIR", dir.path())
            .env("PERF_TEST_CHURN", if churn { "1" } else { "0" })
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        let load = Self { child, dir };
        let deadline = Instant::now() + Duration::from_secs(5);
        while !load.dir.path().join("ready").exists() {
            assert!(Instant::now() < deadline, "child startup timeout");
            std::thread::sleep(Duration::from_millis(10));
        }
        load
    }
}
impl Drop for Load {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[test]
#[ignore = "only launched as a bounded synthetic child by CLI tests"]
fn synthetic_load() {
    let dir = PathBuf::from(std::env::var_os("PERF_TEST_DIR").expect("child-only test"));
    if std::env::var("PERF_TEST_CHURN").as_deref() == Ok("1") {
        fs::write(dir.join("ready"), b"ready").unwrap();
        let until = Instant::now() + Duration::from_secs(20);
        while Instant::now() < until {
            std::thread::Builder::new()
                .name("perf-churn".into())
                .spawn(|| {
                    let begin = Instant::now();
                    let mut value = 0_u64;
                    while begin.elapsed() < Duration::from_millis(200) {
                        value = std::hint::black_box(value.wrapping_add(1));
                    }
                })
                .unwrap()
                .join()
                .unwrap();
        }
        return;
    }
    std::thread::Builder::new()
        .name("perf-hot".into())
        .spawn(move || {
            let mut memory = vec![0_u8; 16 * 1024 * 1024];
            for i in (0..memory.len()).step_by(4096) {
                memory[i] = 1;
            }
            fs::write(dir.join("ready"), b"ready").unwrap();
            let end = Instant::now() + Duration::from_secs(20);
            while Instant::now() < end {
                let begin = Instant::now();
                let mut value = 0_u64;
                while begin.elapsed() < Duration::from_millis(15) {
                    value = std::hint::black_box(value.wrapping_add(1));
                }
                let mut file = fs::File::create(dir.join("io")).unwrap();
                file.write_all(&memory[..65536]).unwrap();
                file.sync_all().unwrap();
                std::hint::black_box(&memory);
                std::thread::sleep(Duration::from_millis(25));
            }
        })
        .unwrap()
        .join()
        .unwrap();
}

fn capture(load: &Load, root: &Path, context: &str) -> PathBuf {
    capture_with(load, root, context, "350ms", &[])
}

fn capture_with(
    load: &Load,
    root: &Path,
    context: &str,
    duration: &str,
    extra: &[&str],
) -> PathBuf {
    let config = root.join("fixture.qml");
    fs::create_dir_all(root).unwrap();
    fs::write(&config, b"// external synthetic fixture\n").unwrap();
    let runs = root.join("runs");
    let output = Command::new(BIN)
        .args([
            "capture",
            "--pid",
            &load.child.id().to_string(),
            "--duration",
            duration,
            "--settle",
            "0s",
            "--interval-ms",
            "25",
            "--context",
            context,
            "--config-path",
        ])
        .arg(config)
        .args(extra)
        .arg("--output-dir")
        .arg(&runs)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let mut paths: Vec<_> = fs::read_dir(runs)
        .unwrap()
        .map(|e| e.unwrap().path())
        .collect();
    paths.sort();
    let run = paths.pop().unwrap();
    // Nix sandboxes intentionally have no /etc/machine-id. These synthetic
    // captures share a fixture host; do not relax the production identity guard.
    let manifest_path = run.join("manifest.json");
    let mut manifest = json(&manifest_path);
    manifest["context"]["machine_id"] = "synthetic-test-machine".into();
    fs::write(&manifest_path, serde_json::to_vec(&manifest).unwrap()).unwrap();
    run
}

#[test]
fn capture_report_hashes_and_unknowns() {
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let run = capture(&load, root.path(), "synthetic; no display; fixed workload");
    let manifest = json(&run.join("manifest.json"));
    assert_eq!(manifest["status"], "complete");
    let summary = json(&run.join("summary.json"));
    let host = summary["resources"]
        .as_array()
        .unwrap()
        .iter()
        .find(|r| r["label"] == "ui-host" && r["phase"] == "capture")
        .unwrap();
    assert!(host["cpu_percent_one_core"].as_f64().unwrap() > 0.0);
    assert!(host["rss_sampled_peak_bytes"].as_u64().unwrap() >= 16 * 1024 * 1024);
    assert_eq!(summary["acknowledgement"]["median_ms"], Value::Null);
    let html = fs::read_to_string(run.join("report.html")).unwrap();
    assert!(html.contains("GPU utilization unavailable"));
    assert!(!html.contains("<script"));
    assert!(!html.contains("https://"));
    assert!(html.contains("No responsiveness trials measured"));
    assert!(summary["threads"].as_array().unwrap().is_empty());
    // Older schema-1 captures have neither task snapshots nor this protocol key.
    let mut legacy = manifest.clone();
    legacy["settings"]
        .as_object_mut()
        .unwrap()
        .remove("include_threads");
    fs::write(
        run.join("manifest.json"),
        serde_json::to_vec(&legacy).unwrap(),
    )
    .unwrap();
    let report = Command::new(BIN)
        .arg("report")
        .arg("--run")
        .arg(&run)
        .output()
        .unwrap();
    assert!(
        report.status.success(),
        "{}",
        String::from_utf8_lossy(&report.stderr)
    );
    let mut samples = fs::OpenOptions::new()
        .append(true)
        .open(run.join("samples.jsonl"))
        .unwrap();
    samples.write_all(b"{}\n").unwrap();
    let report = Command::new(BIN)
        .arg("report")
        .arg("--run")
        .arg(&run)
        .output()
        .unwrap();
    assert!(!report.status.success());
    assert!(String::from_utf8_lossy(&report.stderr).contains("fingerprint mismatch"));
}

#[test]
fn descriptive_compare_requires_matching_context() {
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let a = capture(&load, root.path(), "identical synthetic conditions");
    let b = capture(&load, root.path(), "identical synthetic conditions");
    let output = root.path().join("comparison");
    let result = Command::new(BIN)
        .args(["compare", "--baseline"])
        .arg(&a)
        .arg("--candidate")
        .arg(&b)
        .arg("--output")
        .arg(&output)
        .output()
        .unwrap();
    assert!(
        result.status.success(),
        "{}\n{}",
        String::from_utf8_lossy(&result.stderr),
        json(&output.join("comparison.json"))
    );
    assert_eq!(
        json(&output.join("comparison.json"))["status"],
        "comparable_descriptive_only"
    );
    let c = capture(&load, root.path(), "different workload");
    let output = root.path().join("mismatch");
    let result = Command::new(BIN)
        .args(["compare", "--baseline"])
        .arg(&a)
        .arg("--candidate")
        .arg(&c)
        .arg("--output")
        .arg(&output)
        .output()
        .unwrap();
    assert!(!result.status.success());
    let comparison = json(&output.join("comparison.json"));
    assert_eq!(comparison["status"], "incomparable");
    assert!(comparison["deltas"].is_null());
}

#[test]
fn interruption_finalizes_partial_evidence_and_leaves_target_alive() {
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let mut lens = Command::new(BIN)
        .args([
            "capture",
            "--pid",
            &load.child.id().to_string(),
            "--duration",
            "10s",
            "--settle",
            "0",
            "--interval-ms",
            "25",
            "--output-dir",
        ])
        .arg(root.path())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    let end = Instant::now() + Duration::from_secs(5);
    let run = loop {
        let paths: Vec<_> = fs::read_dir(root.path())
            .unwrap()
            .map(|e| e.unwrap().path())
            .collect();
        if let Some(path) = paths.first() {
            if fs::metadata(path.join("samples.jsonl")).is_ok_and(|m| m.len() > 1000) {
                break path.clone();
            }
        }
        assert!(Instant::now() < end);
        std::thread::sleep(Duration::from_millis(10));
    };
    // SAFETY: send SIGINT only to the test-owned lens child.
    assert_eq!(unsafe { libc::kill(lens.id() as i32, libc::SIGINT) }, 0);
    let deadline = Instant::now() + Duration::from_secs(5);
    let status = loop {
        if let Some(status) = lens.try_wait().unwrap() {
            break status;
        }
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(10));
    };
    assert_eq!(status.code(), Some(130));
    assert_eq!(json(&run.join("manifest.json"))["status"], "partial");
    assert!(run.join("report.html").exists());
    assert!(Path::new(&format!("/proc/{}", load.child.id())).exists());
}

#[test]
fn rehashed_truncated_jsonl_is_still_rejected() {
    use sha2::{Digest, Sha256};
    let load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let run = capture(&load, root.path(), "synthetic");
    let path = run.join("samples.jsonl");
    let mut bytes = fs::read(&path).unwrap();
    bytes.pop(); // valid JSON object, but missing its newline: interrupted writer
    fs::write(&path, &bytes).unwrap();
    let mut manifest = json(&run.join("manifest.json"));
    manifest["hashes"]["samples.jsonl"] = format!("{:x}", Sha256::digest(&bytes)).into();
    fs::write(
        run.join("manifest.json"),
        serde_json::to_vec(&manifest).unwrap(),
    )
    .unwrap();
    let result = Command::new(BIN)
        .args(["report", "--run"])
        .arg(&run)
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("truncated JSONL"));
}

#[test]
fn primary_exit_preserves_partial_run() {
    let mut load = Load::start();
    let root = tempfile::tempdir().unwrap();
    let mut lens = Command::new(BIN)
        .args([
            "capture",
            "--pid",
            &load.child.id().to_string(),
            "--duration",
            "5s",
            "--settle",
            "0",
            "--interval-ms",
            "25",
            "--output-dir",
        ])
        .arg(root.path())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    let run = loop {
        if let Some(entry) = fs::read_dir(root.path()).unwrap().next() {
            let run = entry.unwrap().path();
            if fs::metadata(run.join("samples.jsonl")).is_ok_and(|m| m.len() > 1000) {
                break run;
            }
        }
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(10));
    };
    load.child.kill().unwrap();
    load.child.wait().unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        if let Some(status) = lens.try_wait().unwrap() {
            assert!(!status.success());
            break;
        }
        assert!(Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(10));
    }
    assert_eq!(json(&run.join("manifest.json"))["status"], "partial");
    assert!(run.join("report.html").exists());
}

#[test]
fn controls_fail_closed_before_launching_ipc() {
    let root = tempfile::tempdir().unwrap();
    let result = Command::new(BIN)
        .args([
            "run",
            "warm-open",
            "--pid",
            &std::process::id().to_string(),
            "--quickshell",
            "/definitely/not/a/program",
            "--output-dir",
        ])
        .arg(root.path())
        .output()
        .unwrap();
    assert!(!result.status.success());
    assert!(String::from_utf8_lossy(&result.stderr).contains("requires both"));
    assert_eq!(fs::read_dir(root.path()).unwrap().count(), 0);
    let result = Command::new(BIN)
        .args(["capture", "--pid", "0", "--duration", "nan"])
        .output()
        .unwrap();
    assert!(!result.status.success());
}
