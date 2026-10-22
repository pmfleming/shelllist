//! Investigation only: retained descriptors do not replace executable/UID fences.
use super::*;
use std::{
    fs::File,
    io::{BufRead, BufReader, Read, Seek, SeekFrom, Write},
    os::fd::{AsRawFd, FromRawFd},
    process::{Child, Command, Stdio},
    time::{Duration, Instant},
};

struct OwnedChild(Child);
impl Drop for OwnedChild {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn retained(pid: u32) -> Vec<File> {
    ["stat", "status", "io"]
        .into_iter()
        .map(|name| File::open(format!("/proc/{pid}/{name}")).unwrap())
        .collect()
}

fn reread(file: &mut File, text: &mut String) -> std::io::Result<()> {
    file.seek(SeekFrom::Start(0))?;
    text.clear();
    file.read_to_string(text)?;
    Ok(())
}

fn exited(fd: &File) -> bool {
    let mut poll = libc::pollfd {
        fd: fd.as_raw_fd(),
        events: libc::POLLIN,
        revents: 0,
    };
    // SAFETY: one initialized pollfd, zero timeout; no descriptor ownership transfer.
    assert!(unsafe { libc::poll(&mut poll, 1, 0) } >= 0);
    poll.revents != 0
}

#[test]
fn held_proc_descriptors_and_pidfd_do_not_detect_exec_identity_changes() {
    let mut child = OwnedChild(
        Command::new("sh")
            .args([
                "-c",
                "printf 'ready\\n'; IFS= read -r command; exec sleep 10",
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .unwrap(),
    );
    let mut ready = String::new();
    BufReader::new(child.0.stdout.take().unwrap())
        .read_line(&mut ready)
        .unwrap();
    assert_eq!(ready, "ready\n");
    let id = identity(child.0.id()).unwrap();
    let mut files = retained(id.pid);
    // SAFETY: pidfd_open returns a new owned fd on success, with flags=0.
    let raw = unsafe { libc::syscall(libc::SYS_pidfd_open, id.pid, 0) };
    assert!(raw >= 0, "pidfd_open: {}", std::io::Error::last_os_error());
    let pidfd = unsafe { File::from_raw_fd(raw as i32) };
    assert!(!exited(&pidfd));
    child.0.stdin.take().unwrap().write_all(b"exec\n").unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    while fs::read_link(format!("/proc/{}/exe", id.pid))
        .unwrap()
        .to_string_lossy()
        == id.executable
    {
        assert!(Instant::now() < deadline, "owned child did not exec");
        std::thread::sleep(Duration::from_millis(5));
    }
    assert!(!exited(&pidfd), "pidfd tracks lifetime, not exec");
    let mut text = String::new();
    reread(&mut files[0], &mut text).unwrap();
    assert_eq!(parse_stat(&text).unwrap().start_ticks, id.start_ticks);
    assert!(
        verify(&id).is_err(),
        "the executable fence must still reject exec-in-place"
    );
    child.0.kill().unwrap();
    child.0.wait().unwrap();
    assert!(exited(&pidfd));
    assert!(verify(&id).is_err());
    for (name, file) in ["stat", "status", "io"].into_iter().zip(&mut files) {
        let result = reread(file, &mut text);
        eprintln!(
            "held /proc/{name} after reaped exit: error={:?} bytes={}",
            result.as_ref().err().map(std::io::Error::raw_os_error),
            text.len()
        );
        // Kernel details can vary: lifetime/identity checks, not this return
        // value, are the safety boundary for any future retained-fd collector.
    }
}

#[test]
#[ignore = "release-only held procfs descriptor cost probe"]
fn profile_reopened_and_retained_proc_files_with_identity_fences() {
    let id = identity(std::process::id()).unwrap();
    let mut files = retained(id.pid);
    let paths = ["stat", "status", "io"].map(|name| format!("/proc/{}/{name}", id.pid));
    let mut text = String::new();
    for run in 1..=3 {
        for held in [false, true] {
            let start = Instant::now();
            for _ in 0..1000 {
                verify(&id).unwrap();
                if held {
                    for file in &mut files {
                        reread(file, &mut text).unwrap();
                        std::hint::black_box(&text);
                    }
                } else {
                    for path in &paths {
                        reread(&mut File::open(path).unwrap(), &mut text).unwrap();
                        std::hint::black_box(&text);
                    }
                }
                verify(&id).unwrap();
            }
            eprintln!(
                "run={run} held={held} samples=1000 elapsed_ms={:.3}",
                start.elapsed().as_secs_f64() * 1000.0
            );
        }
    }
}
