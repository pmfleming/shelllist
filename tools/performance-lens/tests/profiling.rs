//! Native adapter process boundaries without launching a desktop or Python.
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::Path,
    process::{Command, Stdio},
    time::{Duration, Instant},
};

fn executable(path: &Path, body: &str) {
    let sh = std::env::split_paths(&std::env::var_os("PATH").unwrap())
        .map(|p| p.join("sh"))
        .find(|p| p.is_file())
        .unwrap();
    fs::write(path, format!("#!{}\nset -eu\n{body}\n", sh.display())).unwrap();
    fs::set_permissions(path, fs::Permissions::from_mode(0o755)).unwrap();
}
fn fixture() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    fs::create_dir_all(dir.path().join("bin")).unwrap();
    fs::create_dir_all(dir.path().join("target/profiling")).unwrap();
    fs::write(dir.path().join("Source.qml"), "Item {}\n").unwrap();
    fs::write(
        dir.path().join("qmlqualitylens.config.json"),
        r#"{"source_roots":["."]}"#,
    )
    .unwrap();
    for report in ["coverage.json", "runtime.json"] {
        fs::write(
            dir.path().join("target/profiling").join(report),
            "old success",
        )
        .unwrap();
    }
    executable(&dir.path().join("bin/qmllint"), "echo 'qmllint 6.11.1'");
    dir
}
fn command(root: &Path) -> Command {
    let mut command = Command::new(env!("CARGO_BIN_EXE_shelllist-perf"));
    command
        .args(["profile-qml", "--root"])
        .arg(root)
        .env(
            "PATH",
            std::env::join_paths(
                std::iter::once(root.join("bin"))
                    .chain(std::env::split_paths(&std::env::var_os("PATH").unwrap())),
            )
            .unwrap(),
        )
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    command
}
#[test]
fn profiler_preserves_environment_and_rejects_failure_or_stale_sources() {
    let dir = fixture();
    let root = dir.path();
    let body = r#"
[ "$QT_QPA_PLATFORM" = offscreen ]
[ "$QT_QUICK_BACKEND" = software ]
[ "$QML_XHR_ALLOW_FILE_READ" = 1 ]
[ "$TZ" = UTC ]
while [ "$1" != --output ]; do shift; done
shift
printf '<trace><event index="1"><type>Binding</type><filename>file://%s/Source.qml</filename><line>1</line></event><range eventIndex="1" duration="2000000"/></trace>' "$PWD" > "$1"
"#;
    executable(&root.join("bin/qmlprofiler"), body);
    assert!(command(root).status().unwrap().success());
    let runtime: serde_json::Value =
        serde_json::from_slice(&fs::read(root.join("target/profiling/runtime.json")).unwrap())
            .unwrap();
    assert_eq!(runtime["events"][0]["duration_ms"], 2.0);
    assert_eq!(runtime["environment"]["qt"], "6.11.1");
    assert_eq!(runtime["environment"]["frames_measured"], false);
    for failing in [
        format!("{body}\nprintf changed >> Source.qml"),
        "exit 1".into(),
    ] {
        executable(&root.join("bin/qmlprofiler"), &failing);
        assert!(!command(root).status().unwrap().success());
        assert!(!root.join("target/profiling/coverage.json").exists());
        assert!(!root.join("target/profiling/runtime.json").exists());
    }
}
#[test]
fn interruption_and_success_both_retire_profiler_descendants() {
    for interrupt in [true, false] {
        let dir = fixture();
        let root = dir.path();
        executable(
            &root.join("bin/qmlprofiler"),
            &format!(
                "trap '' TERM\nsleep 60 &\necho $! > child.pid\n{}",
                if interrupt { "wait" } else { "exit 0" }
            ),
        );
        let mut child = command(root).spawn().unwrap();
        let deadline = Instant::now() + Duration::from_secs(5);
        while !root.join("child.pid").exists() && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert!(root.join("child.pid").exists());
        if interrupt {
            // SAFETY: this PID is our own live child, not the observed desktop.
            unsafe {
                libc::kill(child.id() as i32, libc::SIGTERM);
            }
        }
        while child.try_wait().unwrap().is_none() && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        if child.try_wait().unwrap().is_none() {
            child.kill().unwrap();
            panic!("adapter failed to stop");
        }
        let pid = fs::read_to_string(root.join("child.pid")).unwrap();
        let stat = format!("/proc/{}/stat", pid.trim());
        let deadline = Instant::now() + Duration::from_secs(2);
        loop {
            match fs::read_to_string(&stat) {
                Err(_) => break,
                Ok(s) if s.rsplit_once(')').unwrap().1.trim_start().starts_with('Z') => break,
                _ if Instant::now() >= deadline => {
                    unsafe {
                        libc::kill(pid.trim().parse().unwrap(), libc::SIGKILL);
                    }
                    panic!("profiler descendant survived");
                }
                _ => std::thread::sleep(Duration::from_millis(10)),
            }
        }
        assert!(!root.join("target/profiling/runtime.json").exists());
    }
}
