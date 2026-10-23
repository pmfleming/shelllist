use anyhow::{Context, Result, ensure};
use serde_json::Value;
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::{Component, Path, PathBuf},
};
use walkdir::WalkDir;

fn read_toml(path: &Path) -> Result<toml::Value> {
    toml::from_str(&fs::read_to_string(path).with_context(|| path.display().to_string())?)
        .with_context(|| path.display().to_string())
}
fn strings(value: &Value) -> Result<BTreeSet<String>> {
    value
        .as_array()
        .context("expected array")?
        .iter()
        .map(|s| Ok(s.as_str().context("expected string")?.to_owned()))
        .collect()
}
fn objects(value: &Value) -> impl Iterator<Item = (&String, &Value)> {
    value.as_object().into_iter().flatten()
}
fn dependencies(document: &toml::Value) -> Vec<(String, toml::Value)> {
    let mut result = Vec::new();
    for section in ["dependencies", "dev-dependencies", "build-dependencies"] {
        if let Some(table) = document.get(section).and_then(toml::Value::as_table) {
            for (name, spec) in table {
                result.push((
                    name.clone(),
                    if let Some(version) = spec.as_str() {
                        toml::Value::Table(
                            [("version".into(), toml::Value::String(version.into()))]
                                .into_iter()
                                .collect(),
                        )
                    } else {
                        spec.clone()
                    },
                ));
            }
        }
    }
    if let Some(targets) = document.get("target").and_then(toml::Value::as_table) {
        for target in targets.values() {
            result.extend(dependencies(target));
        }
    }
    result
}
fn logical(path: &Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                if !result.pop() {
                    result.push("..");
                }
            }
            other => result.push(other.as_os_str()),
        }
    }
    result
}
fn version(value: &str) -> Result<Vec<u32>> {
    let mut parts = value
        .split('.')
        .map(str::parse)
        .collect::<std::result::Result<Vec<u32>, _>>()?;
    parts.resize(3, 0);
    Ok(parts)
}
fn search_files(root: &Path) -> Result<BTreeMap<PathBuf, Vec<u8>>> {
    let mut files = BTreeMap::from([(
        PathBuf::from("Cargo.toml"),
        fs::read(root.join("Cargo.toml"))?,
    )]);
    for entry in WalkDir::new(root.join("src")) {
        let entry = entry?;
        if entry.file_type().is_file() {
            files.insert(
                entry.path().strip_prefix(root)?.to_owned(),
                fs::read(entry.path())?,
            );
        }
    }
    Ok(files)
}
pub fn audit(policy: &Value, sources: &BTreeMap<String, PathBuf>) -> Result<Vec<String>> {
    let mut errors = Vec::new();
    macro_rules! require { ($test:expr,$($arg:tt)*) => { if !$test { errors.push(format!($($arg)*)); } }; }
    let repos = strings(&policy["repositories"])?;
    require!(
        sources.keys().cloned().collect::<BTreeSet<_>>() == repos,
        "captured repository set differs from policy"
    );
    if !errors.is_empty() {
        return Ok(errors);
    }
    let expected_manifests = strings(&policy["manifests"])?;
    let locks = strings(&policy["locks"])?;
    let rust = policy["rust"].as_str().context("missing Rust policy")?;
    let mut manifests = BTreeMap::new();
    let mut discovered_locks = BTreeSet::new();
    let ci = regex::Regex::new(r"(?m)^\s*(?:-\s*)?uses:\s*dtolnay/rust-toolchain@([^\s#]+)")?;
    for (repo, root) in sources {
        require!(
            read_toml(&root.join("rust-toolchain.toml"))?
                .get("toolchain")
                .and_then(|t| t.get("channel"))
                .and_then(toml::Value::as_str)
                == Some(rust),
            "{repo}: rustup compiler differs from product compiler"
        );
        let workflows = root.join(".github/workflows");
        if workflows.exists() {
            for entry in fs::read_dir(workflows)? {
                let path = entry?.path();
                if matches!(
                    path.extension().and_then(|s| s.to_str()),
                    Some("yml" | "yaml")
                ) {
                    for captures in ci.captures_iter(&fs::read_to_string(&path)?) {
                        require!(&captures[1] == rust, "{repo}: CI compiler pin drift");
                    }
                }
            }
        }
        if repo != "update-daemon" {
            let lock: Value = serde_json::from_slice(&fs::read(root.join("flake.lock"))?)?;
            let name = lock["nodes"]["root"]["inputs"]["nixpkgs"]
                .as_str()
                .context("nixpkgs node")?;
            require!(
                lock["nodes"][name]["locked"] == policy["nixpkgs"],
                "{repo}: nixpkgs pin drift"
            );
        }
        for entry in WalkDir::new(root).into_iter().filter_entry(|e| {
            ![".git", "target", "node_modules"]
                .iter()
                .any(|n| e.file_name() == *n)
        }) {
            let entry = entry?;
            if !entry.path().is_file() {
                continue;
            }
            if entry.file_name() == "Cargo.toml" || entry.file_name() == "Cargo.lock" {
                ensure!(
                    entry
                        .path()
                        .canonicalize()?
                        .starts_with(root.canonicalize()?),
                    "manifest/lock symlink escapes captured repository: {}",
                    entry.path().display()
                );
            }
            let path = format!("{repo}/{}", entry.path().strip_prefix(root)?.display());
            if entry.file_name() == "Cargo.toml" {
                manifests.insert(path, read_toml(entry.path())?);
            } else if entry.file_name() == "Cargo.lock" {
                discovered_locks.insert(path);
            }
        }
    }
    for (path, reason) in objects(&policy["independentCrates"]) {
        require!(
            reason.as_str().is_some_and(|s| !s.trim().is_empty()),
            "{path}: undocumented independent crate"
        );
        require!(
            !expected_manifests.contains(path),
            "{path}: independent crate is also a product manifest"
        );
        if let Some(manifest) = manifests.remove(path) {
            require!(
                manifest.get("package").is_some()
                    && manifest
                        .get("workspace")
                        .and_then(toml::Value::as_table)
                        .is_some_and(|t| t.is_empty()),
                "{path}: independent crate must declare an empty standalone workspace"
            );
            let lock = Path::new(path)
                .with_file_name("Cargo.lock")
                .to_string_lossy()
                .into_owned();
            require!(
                discovered_locks.contains(&lock)
                    && !locks.contains(&lock)
                    && policy["nonOwningLocks"].get(&lock).is_none(),
                "{path}: independent crate must own a separate lockfile"
            );
            discovered_locks.remove(&lock);
        } else {
            errors.push(format!("{path}: stale independent crate"));
        }
    }
    let actual_manifests = manifests.keys().cloned().collect::<BTreeSet<_>>();
    require!(
        actual_manifests == expected_manifests,
        "manifest inventory changed: {:?}",
        actual_manifests
            .symmetric_difference(&expected_manifests)
            .collect::<Vec<_>>()
    );
    for (path, reason) in objects(&policy["nonOwningLocks"]) {
        require!(
            reason.as_str().is_some_and(|s| !s.trim().is_empty()),
            "{path}: undocumented non-owning lock"
        );
        discovered_locks.remove(path);
    }
    require!(
        discovered_locks == locks,
        "lock inventory changed: {:?}",
        discovered_locks
            .symmetric_difference(&locks)
            .collect::<Vec<_>>()
    );
    let mut uses: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
    let mut direct: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
    for (path, manifest) in &manifests {
        if let Some(minimum) = manifest
            .get("package")
            .or_else(|| manifest.get("workspace").and_then(|w| w.get("package")))
            .and_then(|p| p.get("rust-version"))
            .and_then(toml::Value::as_str)
        {
            require!(
                version(minimum)? <= version(rust)?,
                "{path}: MSRV exceeds product compiler"
            );
        }
        for (alias, spec) in dependencies(manifest) {
            if let Some(relative) = spec.get("path").and_then(toml::Value::as_str) {
                let dest = logical(
                    &Path::new(path)
                        .parent()
                        .unwrap()
                        .join(relative)
                        .join("Cargo.toml"),
                )
                .to_string_lossy()
                .into_owned();
                require!(
                    manifests.contains_key(&dest),
                    "{path}: uncaptured path dependency {dest}"
                );
                require!(
                    !["git", "rev", "branch", "tag"]
                        .iter()
                        .any(|k| spec.get(k).is_some()),
                    "{path}: mixed path/Git dependency {alias}"
                );
                continue;
            }
            let name = spec
                .get("package")
                .and_then(toml::Value::as_str)
                .unwrap_or(&alias)
                .to_owned();
            uses.entry(name.clone()).or_default().insert(path.clone());
            let owner = locks
                .iter()
                .filter(|lock| Path::new(path).starts_with(Path::new(lock).parent().unwrap()))
                .max_by_key(|lock| lock.len());
            require!(owner.is_some(), "{path}: no captured owning lockfile");
            if let Some(owner) = owner {
                direct
                    .entry(owner.clone())
                    .or_default()
                    .insert(name.clone());
            }
            if let Some(rule) = policy["shared"].get(&name) {
                let expected = rule["requirementExceptions"]
                    .get(path)
                    .map(|r| &r["requirement"])
                    .unwrap_or(&rule["requirement"]);
                require!(
                    spec.get("version").and_then(toml::Value::as_str) == expected.as_str()
                        && spec.get("git").is_none(),
                    "{path}: {name} requirement must be {expected}"
                );
            }
        }
    }
    let unmanaged: Vec<_> = uses
        .iter()
        .filter(|(name, paths)| paths.len() > 1 && policy["shared"].get(name.as_str()).is_none())
        .map(|(name, _)| name)
        .collect();
    require!(
        unmanaged.is_empty(),
        "unmanaged shared dependencies: {unmanaged:?}"
    );
    for lock_path in &locks {
        let (repo, relative) = lock_path.split_once('/').context("invalid lock path")?;
        let lock = read_toml(
            &sources
                .get(repo)
                .context("uncaptured lock repository")?
                .join(relative),
        )?;
        let packages = lock
            .get("package")
            .and_then(toml::Value::as_array)
            .context("lock packages missing")?;
        let names: BTreeSet<_> = packages
            .iter()
            .filter_map(|p| p.get("name").and_then(toml::Value::as_str))
            .collect();
        require!(
            direct
                .get(lock_path)
                .into_iter()
                .flatten()
                .all(|n| names.contains(n.as_str())),
            "{lock_path}: declared dependency missing from lock"
        );
        for (name, rule) in objects(&policy["shared"]) {
            let found: Vec<_> = packages
                .iter()
                .filter(|p| p.get("name").and_then(toml::Value::as_str) == Some(name))
                .collect();
            if found.is_empty() {
                continue;
            }
            let expected: Vec<String> =
                if let Some(exception) = rule["lockExceptions"].get(lock_path) {
                    exception["versions"]
                        .as_array()
                        .context("exception versions")?
                        .iter()
                        .map(|v| v.as_str().context("version").map(str::to_owned))
                        .collect::<Result<_>>()?
                } else {
                    vec![
                        rule["version"]
                            .as_str()
                            .context("shared version")?
                            .to_owned(),
                    ]
                };
            let mut actual = found
                .iter()
                .map(|p| {
                    p.get("version")
                        .and_then(toml::Value::as_str)
                        .unwrap_or("")
                        .to_owned()
                })
                .collect::<Vec<_>>();
            let mut expected = expected;
            actual.sort();
            expected.sort();
            require!(
                actual == expected,
                "{lock_path}: {name} resolution drift (expected {expected:?})"
            );
            require!(
                found
                    .iter()
                    .all(|p| p.get("source").and_then(toml::Value::as_str)
                        == Some("registry+https://github.com/rust-lang/crates.io-index")
                        && p.get("checksum")
                            .and_then(toml::Value::as_str)
                            .is_some_and(|s| !s.is_empty())),
                "{lock_path}: {name} source/checksum drift"
            );
        }
    }
    for (name, rule) in objects(&policy["shared"]) {
        for kind in ["requirementExceptions", "lockExceptions"] {
            for (path, exception) in objects(&rule[kind]) {
                require!(
                    exception["reason"]
                        .as_str()
                        .is_some_and(|s| !s.trim().is_empty()),
                    "{name}/{path}: undocumented exception"
                );
                require!(
                    if kind == "requirementExceptions" {
                        manifests.contains_key(path)
                    } else {
                        locks.contains(path)
                    },
                    "{name}/{path}: stale exception"
                );
            }
        }
    }
    require!(
        search_files(
            &sources
                .get("shelllist")
                .context("missing canonical search repository")?
                .join("rust/shelllist-search")
        )? == search_files(
            &sources
                .get("clip-daemon")
                .context("missing vendored search repository")?
                .join("vendor/shelllist-search")
        )?,
        "vendored search differs from canonical source"
    );
    Ok(errors)
}
pub fn check(root: &Path, sources: Option<&Path>, policy: Option<&Path>) -> Result<()> {
    let policy: Value = serde_json::from_slice(&fs::read(
        policy
            .map(Path::to_owned)
            .unwrap_or_else(|| root.join("contracts/build-inputs.json")),
    )?)?;
    let sources: BTreeMap<String, PathBuf> = if let Some(path) = sources {
        serde_json::from_slice(&fs::read(path)?)?
    } else {
        let root = root.canonicalize()?;
        let parent = root.parent().context("missing parent")?;
        strings(&policy["repositories"])?
            .into_iter()
            .map(|repo| {
                let path = parent.join(&repo);
                (repo, path)
            })
            .collect()
    };
    let errors = audit(&policy, &sources)?;
    ensure!(errors.is_empty(), "{}", errors.join("\n"));
    println!(
        "build inputs aligned: Rust {}, {} locked roots, {} shared dependencies",
        policy["rust"].as_str().unwrap_or("?"),
        policy["locks"].as_array().map_or(0, Vec::len),
        policy["shared"].as_object().map_or(0, serde_json::Map::len)
    );
    Ok(())
}
#[cfg(test)]
mod tests;
