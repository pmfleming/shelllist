use crate::{command, model::Target, procfs};
use anyhow::{Context, Result, bail, ensure};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Path, PathBuf},
    time::Duration,
};

pub fn targets(
    pid: u32,
    service_members: bool,
    related: bool,
    extra: &[String],
) -> Result<(Vec<Target>, Vec<String>)> {
    let mut targets = vec![Target {
        label: "ui-host".into(),
        identity: procfs::identity(pid)?,
    }];
    let mut seen = BTreeSet::from([pid]);
    let mut warnings = Vec::new();
    if service_members {
        let group = cgroup(pid)?;
        ensure!(
            group.ends_with("/shelllist.service"),
            "service member discovery requires an exact shelllist.service cgroup; use --related-pid for other processes"
        );
        for member in members(&group)? {
            if seen.insert(member) {
                match procfs::identity(member) {
                    Ok(identity) => targets.push(Target {
                        label: format!("ui-service-member:{member}"),
                        identity,
                    }),
                    Err(e) => warnings.push(format!("service member {member}: {e:#}")),
                }
            }
        }
        warnings.push("Service membership is a start-of-run snapshot, not cgroup accounting; newly spawned/short-lived processes are not included. Per-process RSS is not additive physical memory.".into());
    }
    if related {
        let systemctl = command::resolve(Path::new("systemctl"))?;
        for name in [
            "app-daemon",
            "nm-daemon",
            "bt-daemon",
            "clip-daemon",
            "bar-daemon",
        ] {
            let unit = format!("{name}.service");
            let group = command::run(
                &systemctl,
                &[
                    "--user",
                    "show",
                    &unit,
                    "--property=ControlGroup",
                    "--value",
                ],
                Duration::from_secs(2),
                false,
            );
            let discovered = group.and_then(|g| {
                ensure!(!g.trim().is_empty(), "not running/no cgroup");
                members(g.trim())
            });
            match discovered {
                Ok(pids) if !pids.is_empty() => {
                    for member in pids {
                        if seen.insert(member) {
                            match procfs::identity(member) {
                                Ok(identity) => targets.push(Target {
                                    label: format!("related:{name}:{member}"),
                                    identity,
                                }),
                                Err(e) => warnings.push(format!("{name}: {e:#}")),
                            }
                        }
                    }
                }
                Ok(_) => warnings.push(format!("{name}: no running processes")),
                Err(e) => warnings.push(format!("{name}: unavailable: {e:#}")),
            }
        }
        warnings.push("Related daemon activity is not exclusively Shelllist-caused. Membership is fixed at capture start; no services were activated.".into());
    }
    for value in extra {
        let (label, value) = value
            .split_once('=')
            .context("--related-pid must be LABEL=PID")?;
        ensure!(
            !label.is_empty() && label.len() <= 80,
            "invalid process label"
        );
        ensure!(
            label != "ui-host"
                && label != "lens-observer"
                && !label.starts_with("cgroup:")
                && !label.starts_with("related:")
                && !label.starts_with("ui-service-member:"),
            "reserved process label; choose a stable custom name such as bar"
        );
        let pid = value.parse()?;
        ensure!(seen.insert(pid), "duplicate PID {pid}");
        ensure!(!targets.iter().any(|t| t.label == label), "duplicate label");
        targets.push(Target {
            label: label.into(),
            identity: procfs::identity(pid)?,
        });
    }
    let own = std::process::id();
    if seen.insert(own) {
        targets.push(Target {
            label: "lens-observer".into(),
            identity: procfs::identity(own)?,
        });
    }
    ensure!(targets.len() <= 64, "at most 64 processes supported");
    Ok((targets, warnings))
}

pub fn cgroup(pid: u32) -> Result<String> {
    let text = fs::read_to_string(format!("/proc/{pid}/cgroup"))?;
    text.lines()
        .find_map(|line| line.strip_prefix("0::"))
        .map(str::to_owned)
        .context("no cgroup v2 membership")
}

fn members(group: &str) -> Result<Vec<u32>> {
    ensure!(
        group.starts_with('/') && group != "/" && !group.split('/').any(|s| s == ".."),
        "unsafe or root cgroup"
    );
    let root = Path::new("/sys/fs/cgroup")
        .join(group.trim_start_matches('/'))
        .canonicalize()?;
    ensure!(root.starts_with("/sys/fs/cgroup"), "cgroup outside mount");
    let mut stack = vec![root];
    let mut pids = BTreeSet::new();
    let mut visited = 0;
    while let Some(path) = stack.pop() {
        visited += 1;
        ensure!(visited <= 256, "cgroup tree too large");
        for pid in fs::read_to_string(path.join("cgroup.procs"))?.split_whitespace() {
            pids.insert(pid.parse()?);
        }
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            if entry.file_type()?.is_dir() {
                stack.push(entry.path());
            }
        }
    }
    Ok(pids.into_iter().collect())
}

pub fn context(declaration: &str) -> BTreeMap<String, String> {
    let mut context = BTreeMap::new();
    context.insert("operator_conditions".into(), declaration.into());
    for (key, path) in [
        ("host", "/proc/sys/kernel/hostname"),
        ("kernel", "/proc/sys/kernel/osrelease"),
        ("machine_id", "/etc/machine-id"),
    ] {
        if let Ok(text) = fs::read_to_string(path) {
            let value = if key == "machine_id" {
                procfs::hash_file(Path::new(path)).unwrap_or_default()
            } else {
                text.trim().into()
            };
            context.insert(key.into(), value);
        }
    }
    if let Ok(cpu) = fs::read_to_string("/proc/cpuinfo") {
        if let Some(line) = cpu.lines().find(|line| line.starts_with("model name")) {
            context.insert("cpu".into(), line.into());
        }
    }
    for key in [
        "WAYLAND_DISPLAY",
        "XDG_SESSION_TYPE",
        "QT_QUICK_BACKEND",
        "QSG_RHI_BACKEND",
        "QT_SCALE_FACTOR",
    ] {
        context.insert(
            key.into(),
            std::env::var(key).unwrap_or_else(|_| "unset (not proof of target environment)".into()),
        );
    }
    if let Ok(cards) = fs::read_dir("/sys/class/drm") {
        for card in cards.flatten() {
            let name = card.file_name().to_string_lossy().into_owned();
            if name.starts_with("card") && !name.contains('-') {
                for field in ["vendor", "device", "revision"] {
                    if let Ok(value) = fs::read_to_string(card.path().join("device").join(field)) {
                        context.insert(format!("{name}.{field}"), value.trim().into());
                    }
                }
                if let Ok(driver) = fs::read_link(card.path().join("device/driver")) {
                    context.insert(
                        format!("{name}.driver"),
                        driver
                            .file_name()
                            .unwrap_or_default()
                            .to_string_lossy()
                            .into(),
                    );
                }
            }
        }
    }
    context
}

/// Infer only explicit --path/-p arguments; never store arbitrary command lines.
pub fn infer_config(pid: u32) -> Option<PathBuf> {
    let bytes = fs::read(format!("/proc/{pid}/cmdline")).ok()?;
    let argv: Vec<_> = bytes
        .split(|b| *b == 0)
        .filter_map(|s| std::str::from_utf8(s).ok())
        .collect();
    for (i, arg) in argv.iter().enumerate() {
        let value = if *arg == "--path" || *arg == "-p" {
            argv.get(i + 1).copied()
        } else {
            arg.strip_prefix("--path=")
        };
        if let Some(value) = value {
            let mut path = PathBuf::from(value);
            if path.is_relative() {
                path = fs::read_link(format!("/proc/{pid}/cwd")).ok()?.join(path);
            }
            if path.is_dir() {
                path.push("shell.qml");
            }
            if path.is_file() {
                return Some(path);
            }
        }
    }
    None
}

pub fn config_identity(path: &Path) -> Result<serde_json::Value> {
    let path: PathBuf = path.canonicalize()?;
    if !path.is_file() {
        bail!("config path must identify shell.qml, not a directory");
    }
    Ok(
        serde_json::json!({"path": path, "entry_sha256": procfs::hash_file(&path)?, "scope": "entry file only; Nix store config path is immutable, local imports are not fingerprinted"}),
    )
}
