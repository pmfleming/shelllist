use std::{fs, process::Command};
fn command() -> Command {
    Command::new(env!("CARGO_BIN_EXE_shelllist-xtask"))
}
#[test]
fn surface_cli_freshness_and_unknown_command_fail_closed() {
    let dir = tempfile::tempdir().unwrap();
    let root = dir.path();
    fs::create_dir(root.join("contracts")).unwrap();
    fs::create_dir(root.join("shell")).unwrap();
    fs::write(
        root.join("contracts/surface-catalog.json"),
        include_str!("../../../contracts/surface-catalog.json"),
    )
    .unwrap();
    let invoke = |check: bool| {
        let mut c = command();
        c.current_dir("/").arg("--root").arg(root).arg("surfaces");
        if check {
            c.arg("--check");
        }
        c.output().unwrap()
    };
    assert!(!invoke(true).status.success());
    assert!(invoke(false).status.success());
    assert!(invoke(true).status.success());
    fs::write(root.join("shell/SurfaceCatalog.generated.js"), "stale").unwrap();
    assert!(!invoke(true).status.success());
    assert!(
        !command()
            .arg("unknown-task")
            .output()
            .unwrap()
            .status
            .success()
    );
}
#[test]
fn cache_cli_disabled_invalid_limits_and_explicit_consent() {
    for bad in ["-1", "1.5", "", "abc", "４", "18446744073709551615"] {
        assert!(
            !command()
                .args(["trim-cache", "--max-gib", bad])
                .output()
                .unwrap()
                .status
                .success()
        );
    }
    let out = command()
        .current_dir("/")
        .args(["trim-cache", "--max-gib", "0"])
        .output()
        .unwrap();
    assert!(out.status.success());
    assert!(out.stdout.is_empty());
    assert!(
        !command()
            .args(["trim-cache", "--apply", "--dry-run"])
            .output()
            .unwrap()
            .status
            .success()
    );
}
#[test]
fn incomplete_capture_fails_without_panicking() {
    let dir = tempfile::tempdir().unwrap();
    let policy = dir.path().join("policy.json");
    let sources = dir.path().join("sources.json");
    fs::write(
        &policy,
        r#"{"repositories":["shelllist"],"manifests":[],"locks":[],"rust":"1.95.0","shared":{}}"#,
    )
    .unwrap();
    fs::write(
        &sources,
        serde_json::json!({"shelllist":dir.path()}).to_string(),
    )
    .unwrap();
    let out = command()
        .arg("build-inputs")
        .arg("--sources")
        .arg(sources)
        .arg("--policy")
        .arg(policy)
        .output()
        .unwrap();
    assert!(!out.status.success());
    assert!(!String::from_utf8_lossy(&out.stderr).contains("panicked"));
}
