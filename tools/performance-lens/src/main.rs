mod artifacts;
mod cgroup;
mod command;
#[cfg(test)]
mod command_tests;
mod comparison;
#[cfg(test)]
mod comparison_tests;
mod drm;
mod encoding;
mod ipc;
mod model;
mod procfs;
mod report;
mod sampler;
#[cfg(test)]
mod scenario_tests;
mod scenarios;
mod scheduler;
mod target;
mod threads;

use anyhow::{Result, ensure};
use clap::{Args, Parser, Subcommand, ValueEnum};
use ipc::Endpoint;
use model::{Manifest, SCHEMA};
use serde::Deserialize;
use serde_json::json;
use std::{
    collections::{BTreeMap, BTreeSet},
    path::{Path, PathBuf},
    sync::atomic::Ordering,
    time::{Duration, Instant},
};

#[derive(Parser)]
#[command(
    version,
    about = "External Linux performance lens. Passive capture by default; no production integration."
)]
struct Cli {
    /// TOML protocol defaults (otherwise the bundled scenarios.toml).
    #[arg(long, global = true)]
    config: Option<PathBuf>,
    #[command(subcommand)]
    command: Commands,
}
#[derive(Subcommand)]
enum Commands {
    /// Inspect a same-user process and collector capabilities, without changing UI state.
    Doctor {
        #[arg(long)]
        pid: u32,
        /// Also verify PID-targeted Quickshell IPC and read status (never activate services).
        #[arg(long)]
        ipc_check: bool,
        #[arg(long, default_value = "quickshell")]
        quickshell: PathBuf,
    },
    /// Sample an explicit process and optional related processes; no IPC or UI changes.
    Capture {
        #[command(flatten)]
        common: Common,
        #[arg(long,value_parser=duration)]
        duration: Option<Duration>,
        #[arg(long,value_parser=duration)]
        settle: Option<Duration>,
    },
    /// Consent-gated warm opens through existing PID-targeted IPC. No synthetic input.
    Run {
        #[arg(value_enum)]
        scenario: Scenario,
        #[command(flatten)]
        common: Common,
        #[arg(long, default_value = "applications")]
        surface: String,
        #[arg(long)]
        trials: Option<u32>,
        #[arg(long)]
        allow_ui_control: bool,
        /// Confirm no user interaction during the run; existing IPC cannot detect same-panel edits.
        #[arg(long)]
        exclusive_session: bool,
        #[arg(long, default_value = "quickshell")]
        quickshell: PathBuf,
    },
    /// Validate raw hashes/contracts and regenerate offline HTML/CSV/summary.
    Report {
        #[arg(long)]
        run: PathBuf,
    },
    /// Descriptive, context-matched comparison; exits nonzero if incomparable.
    Compare {
        #[arg(long)]
        baseline: PathBuf,
        #[arg(long)]
        candidate: PathBuf,
        #[arg(long)]
        output: PathBuf,
        /// Permit a deliberate executable change in this role (repeatable); no other checks bypassed.
        /// lens-observer permits an observer change, yielding only a conditional comparison.
        #[arg(long)]
        changed_scope: Vec<String>,
    },
}
#[derive(Clone, Copy, ValueEnum)]
enum Scenario {
    WarmOpen,
}
#[derive(Args)]
struct Common {
    #[arg(long)]
    pid: u32,
    #[arg(long)]
    interval_ms: Option<u64>,
    /// PSS/GPU sampling interval; increase to reduce expensive procfs sampling cost.
    #[arg(long)]
    detail_ms: Option<u64>,
    /// Opt-in per-thread CPU localization at main cadence (extra procfs cost; no stack profiling).
    #[arg(long)]
    include_threads: bool,
    /// Per-thread nanosecond CPU, scheduler wait and context switches (not wakeups).
    #[arg(long, requires = "include_threads")]
    include_scheduler: bool,
    /// Also read cgroup v2 totals for selected process scopes (overlaps process accounting).
    #[arg(long)]
    include_cgroups: bool,
    /// Parent for unique run directories; defaults to this tool's runs/ directory.
    #[arg(long)]
    output_dir: Option<PathBuf>,
    /// Matched conditions: display/Hz/scale/backend/power/workload/visibility. Required for comparison.
    #[arg(long, default_value = "")]
    context: String,
    /// Optional deployed shell.qml identity for passive captures.
    #[arg(long)]
    config_path: Option<PathBuf>,
    /// Include current members of the exact shelllist.service cgroup (start-of-run snapshot).
    #[arg(long)]
    include_service_members: bool,
    /// Discover already-running related daemon user-service members; never start them.
    #[arg(long)]
    include_related_daemons: bool,
    /// Additional explicit process scope, repeatable: LABEL=PID.
    #[arg(long)]
    related_pid: Vec<String>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Defaults {
    interval_ms: u64,
    detail_interval_ms: u64,
    capture_seconds: f64,
    settle_seconds: f64,
    trials: u32,
    timeout_ms: u64,
    poll_ms: u64,
    between_trials_ms: u64,
}
impl Defaults {
    fn load(path: Option<&Path>) -> Result<Self> {
        let text = match path {
            Some(path) => std::fs::read_to_string(path)?,
            None => include_str!("../scenarios.toml").into(),
        };
        let d: Self = toml::from_str(&text)?;
        ensure!(
            (20..=10000).contains(&d.interval_ms),
            "interval_ms must be 20..10000"
        );
        ensure!(
            (1000..=60000).contains(&d.detail_interval_ms),
            "detail_interval_ms must be 1000..60000"
        );
        ensure!(
            d.capture_seconds.is_finite() && d.capture_seconds > 0.0 && d.capture_seconds <= 3600.0,
            "capture_seconds must be >0 and <=3600"
        );
        ensure!(
            d.settle_seconds.is_finite() && (0.0..=300.0).contains(&d.settle_seconds),
            "settle_seconds must be 0..300"
        );
        ensure!((1..=1000).contains(&d.trials), "trials must be 1..1000");
        ensure!(
            (100..=30000).contains(&d.timeout_ms),
            "timeout_ms must be 100..30000"
        );
        ensure!((5..=1000).contains(&d.poll_ms), "poll_ms must be 5..1000");
        ensure!(
            (10..=10000).contains(&d.between_trials_ms),
            "between_trials_ms must be 10..10000"
        );
        Ok(d)
    }
}
fn duration(text: &str) -> std::result::Result<Duration, String> {
    let (number, scale) = if let Some(s) = text.strip_suffix("ms") {
        (s, 0.001)
    } else {
        (text.strip_suffix('s').unwrap_or(text), 1.0)
    };
    let seconds = number
        .parse::<f64>()
        .map_err(|_| "expected seconds or milliseconds (60s, 250ms)".to_string())?
        * scale;
    if !seconds.is_finite() || !(0.0..=3600.0).contains(&seconds) {
        return Err("duration must be 0..3600 seconds".into());
    }
    Ok(Duration::from_secs_f64(seconds))
}

fn main() -> std::process::ExitCode {
    match execute() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("shelllist-perf: {e:#}");
            std::process::ExitCode::from(if command::INTERRUPTED.load(Ordering::Relaxed) {
                130
            } else {
                1
            })
        }
    }
}

fn execute() -> Result<()> {
    let cli = Cli::parse();
    command::install_signals()?;
    let defaults = Defaults::load(cli.config.as_deref())?;
    match cli.command {
        Commands::Doctor {
            pid,
            ipc_check,
            quickshell,
        } => {
            let id = procfs::identity(pid)?;
            let target = model::Target {
                label: "ui-host".into(),
                identity: id.clone(),
            };
            let sample = sampler::collect(
                &target,
                0,
                Instant::now(),
                "doctor",
                true,
                sampler::TaskDetail::None,
                &mut BTreeSet::new(),
            );
            let ipc = if ipc_check {
                let ipc = ipc::Ipc::connect(&quickshell, &id)?;
                Some(
                    json!({"instance":ipc.instance,"status":ipc.status(Duration::from_secs(2),false)?,"config_identity":target::config_identity(&ipc.instance.config_path)?}),
                )
            } else {
                None
            };
            println!(
                "{}",
                serde_json::to_string_pretty(
                    &json!({"schema_version":SCHEMA,"target":target,"ticks_per_second":procfs::ticks_per_second()?,"sample":sample,"ipc":ipc,"notes":["Only one observation: no CPU or GPU rate yet.","Passive mode accepts any explicit same-user PID; it does not assert that it is Shelllist."]})
                )?
            );
        }
        Commands::Capture {
            common,
            duration,
            settle,
        } => {
            let duration =
                duration.unwrap_or_else(|| Duration::from_secs_f64(defaults.capture_seconds));
            let settle = settle.unwrap_or_else(|| Duration::from_secs_f64(defaults.settle_seconds));
            ensure!(!duration.is_zero(), "capture duration must be positive");
            ensure!(settle <= Duration::from_secs(300), "settle must be <=300s");
            capture(common, &defaults, duration, settle, None)?;
        }
        Commands::Run {
            scenario: Scenario::WarmOpen,
            common,
            surface,
            trials,
            allow_ui_control,
            exclusive_session,
            quickshell,
        } => {
            ensure!(
                allow_ui_control && exclusive_session,
                "warm-open requires both --allow-ui-control and --exclusive-session; do not interact during the run"
            );
            let trials = trials.unwrap_or(defaults.trials);
            ensure!((1..=1000).contains(&trials), "trials must be 1..1000");
            ensure!(
                !surface.is_empty()
                    && surface.len() <= 80
                    && surface
                        .chars()
                        .all(|c| c.is_ascii_alphanumeric() || c == '-'),
                "invalid surface id"
            );
            let ipc = ipc::Ipc::connect(&quickshell, &procfs::identity(common.pid)?)?;
            scenarios::preflight(&ipc, &surface)?;
            capture(
                common,
                &defaults,
                Duration::ZERO,
                Duration::from_secs_f64(defaults.settle_seconds),
                Some((ipc, surface, trials)),
            )?;
        }
        Commands::Report { run } => {
            let (manifest, samples, events) = artifacts::load(&run)?;
            let summary = report::summarize(&manifest, &samples, &events);
            report::write(&run, &manifest, &summary, &samples, &events)?;
            println!("{}", run.join("report.html").display());
        }
        Commands::Compare {
            baseline,
            candidate,
            output,
            changed_scope,
        } => {
            let compatible = report::compare(&baseline, &candidate, &output, &changed_scope)?;
            println!("{}", output.join("report.html").display());
            ensure!(compatible, "runs are incomparable; see comparison report");
        }
    }
    Ok(())
}

fn capture(
    common: Common,
    defaults: &Defaults,
    duration: Duration,
    settle: Duration,
    active: Option<(ipc::Ipc, String, u32)>,
) -> Result<()> {
    let interval = common.interval_ms.unwrap_or(defaults.interval_ms);
    ensure!(
        (20..=10000).contains(&interval),
        "interval must be 20..10000ms"
    );
    let detail_interval = common.detail_ms.unwrap_or(defaults.detail_interval_ms);
    ensure!(
        (1000..=60000).contains(&detail_interval),
        "detail-ms must be 1000..60000"
    );
    let (targets, mut warnings) = target::targets(
        common.pid,
        common.include_service_members,
        common.include_related_daemons,
        &common.related_pid,
    )?;
    if let Some((ipc, _, _)) = &active {
        ensure!(
            ipc.identity == targets[0].identity,
            "target changed during setup"
        );
    }
    let cgroups = if common.include_cgroups {
        cgroup::discover(&targets, &mut warnings)
    } else {
        vec![]
    };
    let config = match &active {
        Some((ipc, _, _)) => Some(target::config_identity(&ipc.instance.config_path)?),
        None => common
            .config_path
            .clone()
            .or_else(|| target::infer_config(common.pid))
            .as_deref()
            .map(target::config_identity)
            .transpose()?,
    };
    let root = common
        .output_dir
        .unwrap_or_else(|| Path::new(env!("CARGO_MANIFEST_DIR")).join("runs"));
    let path = artifacts::create(&root)?;
    println!("Run: {}", path.display());
    warnings.extend([
        format!("GPU/PSS sampled no faster than {detail_interval}ms; missing fields are not zero. Sampled peaks may miss short bursts."),
        "The UI host includes the bar. Passive capture does not observe visibility or send IPC; --context is an operator declaration.".into(),
        "No automatic display/refresh/backend/power verification. Environment fields describe the lens, not necessarily the target.".into(),
        "No allocator counters, input-to-photon, backend-result readiness, compositor GPU cost or presented-frame pacing.".into(),
        "Observer CPU/RSS covers the Rust lens, not short-lived IPC helpers. Active polling adds real target work.".into(),
    ]);
    let ticks = procfs::ticks_per_second()?;
    let scenario = if active.is_some() {
        "warm-open"
    } else {
        "capture"
    };
    let mut manifest = Manifest {
        schema_version: SCHEMA,
        sample_schema: Some(encoding::SampleSchema::default()),
        run_id: path.file_name().unwrap().to_string_lossy().into(),
        started_unix_ms: scenarios::unix_ms(),
        finished_unix_ms: None,
        status: "running".into(),
        error: None,
        lens_version: env!("CARGO_PKG_VERSION").into(),
        lens_sha256: procfs::hash_file(&std::env::current_exe()?)?,
        ticks_per_second: ticks,
        targets: targets.clone(),
        cgroups: cgroups.clone(),
        scenario: scenario.into(),
        settings: json!({"interval_ms":interval,"heavy_interval_ms":detail_interval,"include_threads":common.include_threads,"include_scheduler":common.include_scheduler,"include_cgroups":common.include_cgroups,"thread_cadence":common.include_threads.then_some("base"),"duration_s":duration.as_secs_f64(),"initial_settle_s":settle.as_secs_f64(),"surface":active.as_ref().map(|(_,s,_)|s),"trials":active.as_ref().map(|(_,_,n)|n),"timeout_ms":defaults.timeout_ms,"poll_ms":defaults.poll_ms,"between_trials_ms":defaults.between_trials_ms,"config_identity":config,"quickshell_path":active.as_ref().map(|(ipc,_,_)|&ipc.program),"command_path":if active.is_some(){"direct_pid_ipc"}else{"none"}}),
        context: target::context(&common.context),
        warnings,
        hashes: BTreeMap::new(),
    };
    artifacts::atomic_json(&path.join("manifest.json"), &manifest)?;
    let samples = artifacts::raw_file(&path.join("samples.jsonl"))?;
    let mut events = artifacts::EventFile::new(artifacts::raw_file(&path.join("events.jsonl"))?);
    let start = Instant::now();
    let control = sampler::Control::new("initial-settle");
    let thread_control = control.clone();
    let worker = std::thread::spawn(move || {
        let stopped = thread_control.stop.clone();
        let result = sampler::run(
            samples,
            targets,
            start,
            sampler::Options {
                interval: Duration::from_millis(interval),
                detail_interval: Duration::from_millis(detail_interval),
                ticks,
                include_threads: common.include_threads,
                include_scheduler: common.include_scheduler,
                cgroups,
            },
            thread_control,
        );
        stopped.store(true, Ordering::Relaxed);
        result
    });
    let outcome = (|| -> Result<()> {
        scenarios::event(
            &mut events,
            start,
            0,
            "initial-settle",
            "run_started",
            json!({"scenario":scenario}),
        )?;
        scenarios::sleep(settle)?;
        ensure!(!worker.is_finished(), "sampler stopped during setup");
        match &active {
            Some((ipc, surface, trials)) => {
                let options = scenarios::WarmOptions {
                    surface,
                    trials: *trials,
                    timeout: Duration::from_millis(defaults.timeout_ms),
                    poll: Duration::from_millis(defaults.poll_ms),
                    settle: Duration::from_millis(defaults.between_trials_ms),
                };
                scenarios::warm_open(ipc, &mut events, start, &control, &options)?;
            }
            None => {
                control.phase("capture");
                let until = Instant::now() + duration;
                while Instant::now() < until {
                    ensure!(
                        !worker.is_finished(),
                        "sampler stopped; target or output may be unavailable"
                    );
                    scenarios::sleep(
                        until
                            .saturating_duration_since(Instant::now())
                            .min(Duration::from_millis(25)),
                    )?;
                }
            }
        }
        Ok(())
    })();
    control.stop.store(true, Ordering::Relaxed);
    let sampled = worker
        .join()
        .map_err(|_| anyhow::anyhow!("sampler thread panicked"))
        .and_then(|r| r);
    manifest.sample_schema = Some(
        control
            .schema
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .clone(),
    );
    let mut errors = Vec::new();
    if let Err(e) = outcome {
        errors.push(format!("{e:#}"));
    }
    if let Err(e) = sampled {
        errors.push(format!("{e:#}"));
    }
    if command::INTERRUPTED.load(Ordering::Relaxed) && errors.is_empty() {
        errors.push("interrupted".into());
    }
    manifest.status = if errors.is_empty() {
        "complete"
    } else {
        "partial"
    }
    .into();
    manifest.error = (!errors.is_empty()).then(|| errors.join("; "));
    if let Err(error) = scenarios::event(
        &mut events,
        start,
        0,
        "end",
        "run_finished",
        json!({"status":manifest.status,"errors":errors}),
    ) {
        errors.push(format!("final event: {error:#}"));
        manifest.status = "partial".into();
        manifest.error = Some(errors.join("; "));
    }
    drop(events);
    artifacts::finish(&path, &mut manifest)?;
    println!("Report: {}", path.join("report.html").display());
    ensure!(
        manifest.status == "complete",
        "run incomplete: {}",
        manifest.error.as_deref().unwrap_or("unknown error")
    );
    Ok(())
}
