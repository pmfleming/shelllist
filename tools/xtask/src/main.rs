mod build_inputs;
mod cache;
mod contracts;
mod surfaces;

use anyhow::{Context, Result, bail};
use clap::{Parser, Subcommand};
use std::{
    path::{Path, PathBuf},
    process::Command,
};

#[derive(Parser)]
#[command(about = "Offline Shelllist development checks; no deployment or hardware operations")]
struct Cli {
    #[arg(long, global = true, default_value = ".")]
    root: PathBuf,
    #[command(subcommand)]
    task: Task,
}
#[derive(Subcommand)]
enum Task {
    /// Generate the surface catalog, or reject missing/stale output.
    Surfaces {
        #[arg(long)]
        check: bool,
    },
    /// Audit captured sources without fetching or resolving dependencies.
    BuildInputs {
        #[arg(long)]
        sources: Option<PathBuf>,
        #[arg(long)]
        policy: Option<PathBuf>,
    },
    /// Report cache cleanup; deletion requires --apply. Never runs cargo clean.
    TrimCache {
        #[arg(long, conflicts_with = "dry_run")]
        apply: bool,
        #[arg(long)]
        dry_run: bool,
        #[arg(long)]
        max_gib: Option<String>,
    },
    /// Compare a producer's offline fixture/registry with the frontend contract.
    Contract {
        daemon: String,
        #[arg(long)]
        bin: PathBuf,
    },
    /// Run producer-owned serde fixture tests and frontend parity checks.
    Contracts {
        /// Use each producer's Nix development environment for native dependencies.
        #[arg(long)]
        nix: bool,
    },
    /// Run real Qt transport/session regression tests (not source extraction).
    CheckDaemonBoundary,
    /// Run the IP validator and editor tests in Qt's actual JS engine.
    CheckIpValidation,
}
fn run(command: &mut Command) -> Result<()> {
    let status = command
        .status()
        .with_context(|| format!("starting {command:?}"))?;
    if !status.success() {
        bail!("{command:?} failed: {status}");
    }
    Ok(())
}
fn qt(root: &Path, files: &[&str]) -> Result<()> {
    let path = std::env::var_os("PATH").context("PATH is unset")?;
    let runner = std::env::split_paths(&path)
        .map(|p| p.join("qmltestrunner"))
        .find(|p| p.is_file())
        .context("qmltestrunner not found; use the Qt development environment")?
        .canonicalize()?;
    let qt_root = runner
        .parent()
        .and_then(Path::parent)
        .context("Qt runner location")?;
    for file in files {
        run(Command::new(&runner)
            .env("QT_QPA_PLATFORM", "offscreen")
            .env("QT_QUICK_BACKEND", "software")
            .env("QML_XHR_ALLOW_FILE_READ", "1")
            .env("TZ", "UTC")
            .arg("-input")
            .arg(root.join(format!("tests/qml/tst_{file}.qml")))
            .arg("-import")
            .arg(root.join("tests/qml/imports"))
            .arg("-import")
            .arg(root.join("qml"))
            .arg("-import")
            .arg(qt_root.join("lib/qt-6/qml"))
            .args(["-o", "-,txt"]))?;
    }
    Ok(())
}
fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.task {
        Task::Surfaces { check } => surfaces::generate(&cli.root, check),
        Task::BuildInputs { sources, policy } => {
            build_inputs::check(&cli.root, sources.as_deref(), policy.as_deref())
        }
        Task::TrimCache { apply, max_gib, .. } => cache::check(&cli.root, max_gib, !apply),
        Task::Contract { daemon, bin } => contracts::check(&cli.root, &daemon, &bin),
        Task::Contracts { nix } => {
            let parent = cli
                .root
                .canonicalize()?
                .parent()
                .context("repository has no parent")?
                .to_owned();
            for daemon in ["app", "bar", "bt", "clip", "nm"] {
                let repo = parent.join(format!("{daemon}-daemon"));
                let binary = contracts::test_and_build(&repo, daemon, nix)?;
                contracts::check(&cli.root, daemon, &binary)?;
            }
            Ok(())
        }
        Task::CheckDaemonBoundary => qt(
            &cli.root,
            &[
                "daemon_bridge",
                "daemon_socket",
                "daemon_sessions",
                "daemon_boundary",
            ],
        ),
        Task::CheckIpValidation => qt(&cli.root, &["ip_validation", "ip_fields", "ip_control"]),
    }
}
