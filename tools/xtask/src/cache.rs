//! Conservative Linux Cargo-cache cleanup. No symlink traversal, cargo clean,
//! repository hooks, or deletion of lock files, source trees or review artifacts.
use anyhow::{Context, Result, ensure};
use std::{
    collections::{BTreeSet, HashSet},
    fs::{self, File, TryLockError},
    os::unix::{ffi::OsStrExt, fs::MetadataExt},
    path::{Path, PathBuf},
    process::Command,
};
use walkdir::WalkDir;
const GIB: u64 = 1024 * 1024 * 1024;
fn inside(path: &Path, root: &Path) -> bool {
    path != root && path.starts_with(root)
}
fn safe_target(target: &Path, root: &Path) -> bool {
    inside(target, root)
        && target.canonicalize().is_ok_and(|p| p == target)
        && !target
            .ancestors()
            .take_while(|p| inside(p, root))
            .any(|p| p.join(".git").symlink_metadata().is_ok())
}
fn protected(path: &Path, tracked: &BTreeSet<PathBuf>) -> Result<bool> {
    if path.symlink_metadata()?.is_symlink() || tracked.iter().any(|p| p.starts_with(path)) {
        return Ok(true);
    }
    if path.is_dir() {
        for entry in WalkDir::new(path) {
            let entry = entry?;
            if entry.file_name() == ".git" || entry.file_name() == "Cargo.toml" {
                return Ok(true);
            }
        }
    }
    Ok(false)
}
fn disk_bytes(path: &Path, excluded: &BTreeSet<PathBuf>) -> Result<u64> {
    let mut seen = HashSet::new();
    let mut bytes = 0u64;
    for entry in WalkDir::new(path)
        .into_iter()
        .filter_entry(|entry| !excluded.iter().any(|p| entry.path().starts_with(p)))
    {
        let entry = entry?;
        let meta = entry.path().symlink_metadata()?;
        if seen.insert((meta.dev(), meta.ino())) {
            bytes = bytes
                .checked_add(
                    meta.blocks()
                        .checked_mul(512)
                        .context("disk size overflow")?,
                )
                .context("disk size overflow")?;
        }
    }
    Ok(bytes)
}
fn directory(path: &Path) -> bool {
    path.symlink_metadata()
        .is_ok_and(|m| m.is_dir() && !m.is_symlink())
}
fn profiles(target: &Path) -> Result<BTreeSet<PathBuf>> {
    let mut bases = vec![target.to_owned()];
    let coverage = target.join("llvm-cov-target");
    if directory(&coverage) {
        bases.push(coverage);
    }
    let triple = regex::Regex::new(
        r"^(?:x86_64|i[3-6]86|aarch64|arm\w*|thumb\w*|wasm\d+|riscv\w*|powerpc\w*|s390x|mips\w*|loongarch\w*)-[\w.-]+$",
    )?;
    for base in bases.clone() {
        for child in fs::read_dir(base)? {
            let child = child?;
            if directory(&child.path()) && triple.is_match(&child.file_name().to_string_lossy()) {
                bases.push(child.path());
            }
        }
    }
    let mut result = BTreeSet::new();
    for base in bases {
        for name in ["debug", "release"] {
            let path = base.join(name);
            let lock = path.join(".cargo-lock");
            if directory(&path)
                && lock
                    .symlink_metadata()
                    .is_ok_and(|m| m.is_file() && !m.is_symlink())
                && (directory(&path.join("deps")) || directory(&path.join(".fingerprint")))
            {
                result.insert(path);
            }
        }
    }
    Ok(result)
}
fn trim(
    root: &Path,
    target: &Path,
    limit: u64,
    dry: bool,
    tracked: &BTreeSet<PathBuf>,
) -> Result<Vec<String>> {
    let mut log = Vec::new();
    if !target.exists() {
        return Ok(log);
    }
    if !safe_target(target, root) {
        log.push(format!(
            "refusing external, nested-repository or symlinked target: {}",
            target.display()
        ));
        return Ok(log);
    }
    let mut remaining = disk_bytes(target, &BTreeSet::new())?;
    if remaining <= limit {
        return Ok(log);
    }
    log.push(format!(
        "{}: {remaining} bytes exceeds {limit}",
        target.display()
    ));
    let mut candidates = Vec::new();
    let mut locks = Vec::new();
    for profile in profiles(target)? {
        if protected(&profile, tracked)? {
            log.push(format!(
                "preserving source/tracked content: {}",
                profile.display()
            ));
            continue;
        }
        let path = profile.join(".cargo-lock");
        let handle = File::open(&path)?;
        match handle.try_lock() {
            Ok(()) => {}
            Err(TryLockError::WouldBlock) => {
                log.push("active build; skipping whole target".into());
                return Ok(log);
            }
            Err(TryLockError::Error(error)) => return Err(error.into()),
        }
        let meta = handle.metadata()?;
        let path_meta = path.symlink_metadata()?;
        ensure!(
            !path_meta.is_symlink()
                && meta.ino() == path_meta.ino()
                && meta.dev() == path_meta.dev(),
            "Cargo lock replaced during admission"
        );
        locks.push(handle);
        candidates.push(profile);
    }
    let mut batches: Vec<Vec<PathBuf>> = candidates
        .iter()
        .map(|p| vec![p.join("incremental")])
        .collect();
    for coverage_pass in [true, false] {
        for profile in &candidates {
            if profile
                .strip_prefix(target)?
                .components()
                .any(|c| c.as_os_str() == "llvm-cov-target")
                == coverage_pass
            {
                let mut children = fs::read_dir(profile)?
                    .map(|c| c.map(|e| e.path()))
                    .collect::<std::io::Result<Vec<_>>>()?;
                children.retain(|p| {
                    !matches!(
                        p.file_name().and_then(|n| n.to_str()),
                        Some(".cargo-lock" | "incremental")
                    )
                });
                children.sort();
                batches.push(children);
            }
        }
    }
    let mut excluded = BTreeSet::new();
    for batch in batches {
        if remaining <= limit {
            break;
        }
        for path in batch {
            if path.symlink_metadata().is_err() || protected(&path, tracked)? {
                continue;
            }
            ensure!(
                safe_target(target, root) && path.canonicalize()? == path,
                "cache path changed during cleanup"
            );
            log.push(format!(
                "{} {}",
                if dry { "would remove" } else { "removing" },
                path.display()
            ));
            if dry {
                excluded.insert(path);
            } else if path.is_dir() {
                fs::remove_dir_all(path)?;
            } else {
                fs::remove_file(path)?;
            }
        }
        remaining = disk_bytes(target, &excluded)?;
    }
    // Keep every acquired Cargo lock alive until after the final accounting.
    drop(locks);
    log.push(format!(
        "{remaining} bytes {}",
        if dry {
            "estimated after cleanup"
        } else {
            "remaining"
        }
    ));
    if remaining > limit {
        log.push("limit still exceeded; preserved reports, snapshots, symlinks and unrecognized content need manual review".into());
    }
    Ok(log)
}
fn git(root: &Path, args: &[&str]) -> Result<Vec<u8>> {
    let output = Command::new("git")
        .args([
            "-c",
            "core.fsmonitor=false",
            "-c",
            "core.hooksPath=/dev/null",
            "-C",
        ])
        .arg(root)
        .args(args)
        .output()?;
    ensure!(
        output.status.success(),
        "Git failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(output.stdout)
}
fn tracked(root: &Path) -> Result<BTreeSet<PathBuf>> {
    let top = git(root, &["rev-parse", "--show-toplevel"])?;
    // Git's path is newline-terminated; do not trim meaningful path whitespace.
    let top = top.strip_suffix(b"\n").unwrap_or(&top);
    ensure!(
        Path::new(std::ffi::OsStr::from_bytes(top)).canonicalize()? == root,
        "expected repository root does not match Git worktree root"
    );
    Ok(git(root, &["ls-files", "-z"])?
        .split(|b| *b == 0)
        .filter(|b| !b.is_empty())
        .map(|b| root.join(std::ffi::OsStr::from_bytes(b)))
        .collect())
}
fn targets(
    root: &Path,
    tracked: &BTreeSet<PathBuf>,
    override_path: Option<std::ffi::OsString>,
) -> Vec<PathBuf> {
    if let Some(path) = override_path.filter(|p| !p.is_empty()) {
        return vec![root.join(path)];
    }
    let mut targets = BTreeSet::from([root.join("target")]);
    targets.extend(
        tracked
            .iter()
            .filter(|p| p.file_name().is_some_and(|n| n == "Cargo.toml"))
            .map(|p| p.parent().unwrap().join("target")),
    );
    targets
        .iter()
        .filter(|p| !targets.iter().any(|q| inside(p, q)))
        .cloned()
        .collect()
}
fn limit(value: &str) -> Result<u64> {
    ensure!(
        !value.is_empty() && value.bytes().all(|b| b.is_ascii_digit()),
        "cache limit must be a non-negative integer"
    );
    value
        .parse::<u64>()?
        .checked_mul(GIB)
        .context("cache limit overflow")
}
pub fn check(root: &Path, max_gib: Option<String>, dry: bool) -> Result<()> {
    let value = max_gib
        .or_else(|| std::env::var("CARGO_TARGET_MAX_GIB").ok())
        .or_else(|| std::env::var("SCRATCHPAD_TARGET_MAX_GIB").ok())
        .unwrap_or("4".into());
    let limit = limit(&value)?;
    if limit == 0 {
        return Ok(());
    }
    let root = root.canonicalize()?;
    let tracked = tracked(&root)?;
    for target in targets(&root, &tracked, std::env::var_os("CARGO_TARGET_DIR")) {
        for line in trim(&root, &target, limit, dry, &tracked)? {
            println!("build-cache: {line}");
        }
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;
    fn file(path: &Path) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, vec![1; 16384]).unwrap();
    }
    fn profile(target: &Path, name: &str) -> PathBuf {
        let p = target.join(name);
        for name in [
            ".cargo-lock",
            ".fingerprint/hash",
            "deps/binary",
            "incremental/object",
        ] {
            file(&p.join(name));
        }
        p
    }
    #[test]
    fn prune_only_recognized_artifacts_preserving_lock_inodes_and_reports() {
        let root = tempfile::tempdir().unwrap();
        let target = root.path().join("target");
        let p = profile(&target, "debug");
        let cross = profile(&target.join("x86_64-unknown-linux-gnu"), "release");
        let inode = fs::metadata(p.join(".cargo-lock")).unwrap().ino();
        file(&target.join("reports/review.json"));
        file(&target.join("review/debug/source"));
        trim(root.path(), &target, 1, false, &BTreeSet::new()).unwrap();
        for p in [&p, &cross] {
            assert_eq!(fs::read_dir(p).unwrap().count(), 1);
        }
        assert_eq!(fs::metadata(p.join(".cargo-lock")).unwrap().ino(), inode);
        assert!(target.join("reports/review.json").exists());
        assert!(target.join("review/debug/source").exists());
    }
    #[test]
    fn dry_run_hardlinks_and_literal_exclusions() {
        let root = tempfile::tempdir().unwrap();
        let target = root.path().join("target");
        let p = profile(&target, "debug");
        fs::hard_link(p.join("deps/binary"), target.join("retained-binary")).unwrap();
        file(&target.join("cache[one]*?"));
        file(&target.join("cacheoXX"));
        let excluded = BTreeSet::from([target.join("cache[one]*?")]);
        let expected = disk_bytes(&target, &excluded).unwrap();
        fs::remove_file(target.join("cache[one]*?")).unwrap();
        assert_eq!(disk_bytes(&target, &BTreeSet::new()).unwrap(), expected);
        let before = disk_bytes(&target, &BTreeSet::new()).unwrap();
        let log = trim(root.path(), &target, 1, true, &BTreeSet::new()).unwrap();
        assert!(log.iter().any(|s| s.contains("would remove")));
        assert_eq!(disk_bytes(&target, &BTreeSet::new()).unwrap(), before);
        assert!(p.join("deps/binary").exists());
        assert!(disk_bytes(&target, &BTreeSet::from([p])).unwrap() >= 16384);
    }
    #[test]
    fn lock_contention_skips_entire_target() {
        let root = tempfile::tempdir().unwrap();
        let target = root.path().join("target");
        let p = profile(&target, "debug");
        let release = profile(&target, "release");
        let lock = File::open(release.join(".cargo-lock")).unwrap();
        lock.lock().unwrap();
        assert!(
            trim(root.path(), &target, 1, false, &BTreeSet::new())
                .unwrap()
                .iter()
                .any(|s| s.contains("active build"))
        );
        assert!(p.join("incremental/object").exists());
    }
    #[test]
    fn never_remove_sources_tracked_files_or_follow_symlinks() {
        let root = tempfile::tempdir().unwrap();
        let target = root.path().join("target");
        let p = profile(&target, "debug");
        for marker in ["Cargo.toml", ".git", "tracked"] {
            let path = p.join("deps/source").join(marker);
            file(&path);
            let tracked = if marker == "tracked" {
                BTreeSet::from([path.clone()])
            } else {
                BTreeSet::new()
            };
            trim(root.path(), &target, 1, false, &tracked).unwrap();
            assert!(p.join("incremental/object").exists());
            fs::remove_file(path).unwrap();
        }
        let external = tempfile::tempdir().unwrap();
        let remote = profile(external.path(), "debug");
        symlink(external.path(), root.path().join("linked")).unwrap();
        file(&root.path().join("nested/.git"));
        let nested = profile(&root.path().join("nested/target"), "debug");
        for path in [
            external.path().to_owned(),
            root.path().join("linked"),
            root.path().join("nested/target"),
        ] {
            assert!(
                trim(root.path(), &path, 1, false, &BTreeSet::new())
                    .unwrap()
                    .iter()
                    .any(|s| s.contains("refusing"))
            );
        }
        symlink(&remote, target.join("release")).unwrap();
        symlink(&remote, p.join("external-link")).unwrap();
        trim(root.path(), &target, 1, false, &BTreeSet::new()).unwrap();
        assert!(remote.join("deps/binary").exists());
        assert!(nested.join("deps/binary").exists());
        assert!(
            p.join("external-link")
                .symlink_metadata()
                .unwrap()
                .is_symlink()
        );
    }
    #[test]
    fn budget_order_discovery_and_limits() {
        for bad in ["", "-1", "1.5", "abc", "４", "18446744073709551615"] {
            assert!(limit(bad).is_err());
        }
        assert_eq!(limit("0").unwrap(), 0);
        let root = tempfile::tempdir().unwrap();
        let target = root.path().join("target");
        let p = profile(&target, "debug");
        let coverage = profile(&target.join("llvm-cov-target"), "debug");
        assert!(
            trim(root.path(), &target, u64::MAX, false, &BTreeSet::new())
                .unwrap()
                .is_empty()
        );
        let log = trim(root.path(), &target, 1, true, &BTreeSet::new()).unwrap();
        let removals: Vec<_> = log
            .iter()
            .filter(|s| s.starts_with("would remove"))
            .collect();
        assert!(removals[0].ends_with("incremental"));
        assert!(removals[1].ends_with("incremental"));
        let coverage_index = removals
            .iter()
            .position(|s| s.ends_with(&format!("{}/deps", coverage.display())))
            .unwrap();
        let normal_index = removals
            .iter()
            .position(|s| s.ends_with(&format!("{}/deps", p.display())))
            .unwrap();
        assert!(coverage_index < normal_index);
        let budget = disk_bytes(&target, &BTreeSet::from([p.join("incremental")])).unwrap();
        trim(root.path(), &target, budget, false, &BTreeSet::new()).unwrap();
        assert!(!p.join("incremental").exists());
        assert!(
            p.join("deps/binary").exists(),
            "stop as soon as the budget is met"
        );
        assert!(coverage.join("incremental/object").exists());
        let tracked = BTreeSet::from([
            root.path().join("tools/x/Cargo.toml"),
            target.join("review/Cargo.toml"),
        ]);
        let paths = targets(root.path(), &tracked, None);
        assert_eq!(paths.len(), 2);
        assert_eq!(
            targets(root.path(), &tracked, Some("custom".into())),
            vec![root.path().join("custom")]
        );
    }
    #[test]
    fn git_does_not_execute_repository_fsmonitor() {
        use std::os::unix::fs::PermissionsExt;
        let root = tempfile::tempdir().unwrap();
        assert!(
            Command::new("git")
                .args(["init", "-q"])
                .arg(root.path())
                .status()
                .unwrap()
                .success()
        );
        file(&root.path().join("Cargo.toml"));
        git(root.path(), &["add", "Cargo.toml"]).unwrap();
        let monitor = root.path().join("monitor");
        fs::write(
            &monitor,
            format!(
                "#!/bin/sh\ntouch '{}'\n",
                root.path().join("executed").display()
            ),
        )
        .unwrap();
        fs::set_permissions(&monitor, fs::Permissions::from_mode(0o755)).unwrap();
        git(
            root.path(),
            &["config", "core.fsmonitor", monitor.to_str().unwrap()],
        )
        .unwrap();
        assert_eq!(
            tracked(root.path()).unwrap(),
            BTreeSet::from([root.path().join("Cargo.toml")])
        );
        assert!(!root.path().join("executed").exists());
    }
}
