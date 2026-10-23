use super::*;
use serde_json::json;
struct Fixture {
    temp: tempfile::TempDir,
    sources: BTreeMap<String, PathBuf>,
    policy: Value,
}
const MANIFESTS: [&str; 2] = [
    "shelllist/rust/shelllist-search/Cargo.toml",
    "clip-daemon/vendor/shelllist-search/Cargo.toml",
];
impl Fixture {
    fn new() -> Self {
        let temp = tempfile::tempdir().unwrap();
        let sources = ["shelllist", "clip-daemon"]
            .into_iter()
            .map(|r| (r.to_owned(), temp.path().join(r)))
            .collect();
        let locks: Vec<_> = MANIFESTS
            .iter()
            .map(|p| {
                Path::new(p)
                    .with_file_name("Cargo.lock")
                    .to_string_lossy()
                    .into_owned()
            })
            .collect();
        let f = Self {
            temp,
            sources,
            policy: json!({"repositories":["shelllist","clip-daemon"],"manifests":MANIFESTS,"locks":locks,"rust":"1.95.0","nixpkgs":{"rev":"pinned"},"shared":{"serde":{"requirement":"1","version":"1.0.229"}}}),
        };
        for repo in ["shelllist", "clip-daemon"] {
            f.put(
                &format!("{repo}/rust-toolchain.toml"),
                "[toolchain]\nchannel = \"1.95.0\"\n",
            );
            f.put(&format!("{repo}/flake.lock"),&json!({"nodes":{"root":{"inputs":{"nixpkgs":"pkgs"}},"pkgs":{"locked":{"rev":"pinned"}}}}).to_string());
        }
        for manifest in MANIFESTS {
            f.put(manifest,"[package]\nname = \"search\"\nversion = \"0.1.0\"\nrust-version = \"1.85\"\n[dependencies]\nserde = \"1\"\n");
            f.put(
                &Path::new(manifest)
                    .parent()
                    .unwrap()
                    .join("src/lib.rs")
                    .to_string_lossy(),
                "// canonical\n",
            );
            f.put(&Path::new(manifest).with_file_name("Cargo.lock").to_string_lossy(),"version = 4\n[[package]]\nname = \"serde\"\nversion = \"1.0.229\"\nsource = \"registry+https://github.com/rust-lang/crates.io-index\"\nchecksum = \"test-only\"\n");
        }
        f
    }
    fn put(&self, path: &str, text: &str) {
        let p = self.temp.path().join(path);
        fs::create_dir_all(p.parent().unwrap()).unwrap();
        fs::write(p, text).unwrap();
    }
    fn replace(&self, path: &str, old: &str, new: &str) {
        let p = self.temp.path().join(path);
        self.put(path, &fs::read_to_string(p).unwrap().replace(old, new));
    }
    fn rejects(&self, reason: &str) {
        let errors = audit(&self.policy, &self.sources).unwrap();
        assert!(
            errors.iter().any(|s| s.contains(reason)),
            "expected {reason}: {errors:?}"
        );
    }
    fn independent(&mut self) -> &'static str {
        let p = "shelllist/tools/lens/Cargo.toml";
        self.put(p,"[package]\nname = \"lens\"\nversion = \"0.1.0\"\n[workspace]\n[dependencies]\nserde = \"2\"\n");
        self.put(
            "shelllist/tools/lens/Cargo.lock",
            "version = 4\npackage = []\n",
        );
        self.policy["independentCrates"] = json!({p:"External development tool"});
        p
    }
}
#[test]
fn aligned_and_missing_sources() {
    let mut f = Fixture::new();
    assert!(audit(&f.policy, &f.sources).unwrap().is_empty());
    f.sources.remove("clip-daemon");
    f.rejects("captured repository set");
}
#[test]
fn compiler_pins_requirements_msrv_and_sources() {
    for (path, old, new, reason) in [
        (
            "shelllist/rust-toolchain.toml",
            "1.95.0",
            "stable",
            "rustup compiler",
        ),
        ("shelllist/flake.lock", "pinned", "other", "nixpkgs pin"),
        (
            MANIFESTS[0],
            "serde = \"1\"",
            "serde = \"2\"",
            "requirement must be",
        ),
        (MANIFESTS[0], "1.85", "1.96", "MSRV exceeds"),
        (
            "shelllist/rust/shelllist-search/Cargo.lock",
            "registry+https://github.com/rust-lang/crates.io-index",
            "git+https://example.invalid/serde",
            "source/checksum",
        ),
    ] {
        let f = Fixture::new();
        f.replace(path, old, new);
        f.rejects(reason);
    }
    let f = Fixture::new();
    f.put(
        "shelllist/.github/workflows/ci.yml",
        "jobs:\n test:\n  steps:\n   - uses: dtolnay/rust-toolchain@stable\n",
    );
    f.rejects("CI compiler pin drift");
    f.replace("shelllist/.github/workflows/ci.yml", "@stable", "@1.95.0");
    assert!(audit(&f.policy, &f.sources).unwrap().is_empty());
}
#[test]
fn inventories_new_dependencies_paths_and_lock_drift() {
    for (path, text, reason) in [
        (
            "shelllist/new/Cargo.toml",
            "[package]\nname=\"new\"",
            "manifest inventory changed",
        ),
        (
            "shelllist/new/Cargo.lock",
            "version=4\npackage=[]",
            "lock inventory changed",
        ),
        (
            "shelllist/rust/shelllist-search/Cargo.lock",
            "version=4\npackage=[]",
            "declared dependency missing",
        ),
        (
            "clip-daemon/vendor/shelllist-search/src/lib.rs",
            "// changed",
            "vendored search differs",
        ),
    ] {
        let f = Fixture::new();
        f.put(path, text);
        f.rejects(reason);
    }
    let f = Fixture::new();
    for p in MANIFESTS {
        f.replace(p, "serde = \"1\"", "serde = \"1\"\ntokio = \"1\"");
    }
    f.rejects("unmanaged shared dependencies");
    let f = Fixture::new();
    f.replace(
        MANIFESTS[0],
        "serde = \"1\"",
        "missing = { path = \"../../../../outside\" }",
    );
    f.rejects("uncaptured path dependency");
    let f = Fixture::new();
    let lock = "shelllist/rust/shelllist-search/Cargo.lock";
    f.replace(lock, "1.0.229", "1.0.228");
    f.rejects("resolution drift");
    let text = fs::read_to_string(f.temp.path().join(lock)).unwrap();
    f.put(
        lock,
        &format!("{text}\n[[package]]\nname=\"serde\"\nversion=\"1.0.229\"\n"),
    );
    f.rejects("resolution drift");
}
#[test]
fn independent_exceptions_are_exact_and_cannot_hide_product_dependencies() {
    let mut f = Fixture::new();
    let p = f.independent();
    assert!(audit(&f.policy, &f.sources).unwrap().is_empty());
    f.put(
        "shelllist/tools/lens/nested/Cargo.toml",
        "[package]\nname=\"nested\"",
    );
    f.put(
        "shelllist/tools/lens/nested/Cargo.lock",
        "version=4\npackage=[]",
    );
    f.rejects("manifest inventory changed");
    f.rejects("lock inventory changed");
    let mut f = Fixture::new();
    f.independent();
    f.replace(
        MANIFESTS[0],
        "serde = \"1\"",
        "lens = { path = \"../../tools/lens\" }",
    );
    f.rejects("uncaptured path dependency shelllist/tools/lens/Cargo.toml");
    let mut f = Fixture::new();
    f.independent();
    f.policy["independentCrates"][p] = json!("");
    f.rejects("undocumented independent crate");
    fs::remove_file(f.temp.path().join(p)).unwrap();
    f.rejects("stale independent crate");
    let mut f = Fixture::new();
    f.independent();
    f.replace(p, "[workspace]\n", "");
    f.rejects("empty standalone workspace");
    fs::remove_file(f.temp.path().join("shelllist/tools/lens/Cargo.lock")).unwrap();
    f.rejects("own a separate lockfile");
    let mut f = Fixture::new();
    f.independent();
    f.policy["manifests"].as_array_mut().unwrap().push(json!(p));
    f.policy["locks"]
        .as_array_mut()
        .unwrap()
        .push(json!("shelllist/tools/lens/Cargo.lock"));
    f.rejects("also a product manifest");
    f.rejects("own a separate lockfile");
}
#[test]
fn documented_requirement_and_resolution_exceptions_are_narrow() {
    let mut f = Fixture::new();
    let lock = "shelllist/rust/shelllist-search/Cargo.lock";
    f.replace(lock, "1.0.229", "1.0.228");
    f.policy["shared"]["serde"]["lockExceptions"] =
        json!({lock:{"versions":["1.0.228"],"reason":"compatibility"}});
    assert!(audit(&f.policy, &f.sources).unwrap().is_empty());
    f.replace(
        "clip-daemon/vendor/shelllist-search/Cargo.lock",
        "1.0.229",
        "1.0.228",
    );
    f.rejects("resolution drift");
    f.policy["shared"]["serde"]["lockExceptions"][lock]
        .as_object_mut()
        .unwrap()
        .remove("reason");
    f.rejects("undocumented exception");
    let mut f = Fixture::new();
    f.replace(MANIFESTS[0], "serde = \"1\"", "serde = \"1.0.229\"");
    f.policy["shared"]["serde"]["requirementExceptions"] =
        json!({MANIFESTS[0]:{"requirement":"1.0.229","reason":"upgrade"}});
    assert_eq!(
        audit(&f.policy, &f.sources).unwrap(),
        vec!["vendored search differs from canonical source"]
    );
    f.replace(MANIFESTS[1], "serde = \"1\"", "serde = \"1.0.229\"");
    f.rejects("requirement must be");
}
