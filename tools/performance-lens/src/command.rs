//! Bounded, shell-free helper execution. Only our own helper process group is killed.
use anyhow::{Context, Result, bail};
use std::{
    fs::File,
    io::{ErrorKind, Read},
    os::{
        fd::{AsRawFd, FromRawFd, IntoRawFd},
        unix::process::CommandExt,
    },
    path::Path,
    process::{Command, Stdio},
    sync::atomic::{AtomicBool, Ordering},
    time::{Duration, Instant},
};

pub static INTERRUPTED: AtomicBool = AtomicBool::new(false);
extern "C" fn interrupt(_: libc::c_int) {
    INTERRUPTED.store(true, Ordering::Relaxed);
}
pub fn install_signals() -> Result<()> {
    // SAFETY: handler only stores to a lock-free AtomicBool, with the C signal ABI.
    unsafe {
        if libc::signal(libc::SIGINT, interrupt as *const () as libc::sighandler_t) == libc::SIG_ERR
            || libc::signal(libc::SIGTERM, interrupt as *const () as libc::sighandler_t)
                == libc::SIG_ERR
        {
            bail!("cannot install interruption handlers");
        }
    }
    Ok(())
}

fn nonblocking(fd: std::os::fd::RawFd) -> Result<File> {
    // SAFETY: ownership of the live pipe fd has been transferred by into_raw_fd.
    let file = unsafe { File::from_raw_fd(fd) };
    // SAFETY: fcntl acts on this owned descriptor, preserving existing flags.
    unsafe {
        let flags = libc::fcntl(file.as_raw_fd(), libc::F_GETFL);
        if flags == -1
            || libc::fcntl(file.as_raw_fd(), libc::F_SETFL, flags | libc::O_NONBLOCK) == -1
        {
            return Err(std::io::Error::last_os_error().into());
        }
    }
    Ok(file)
}

fn drain(file: &mut File, out: &mut Vec<u8>) -> Result<()> {
    let mut buffer = [0; 8192];
    // Bound each drain too: a continuously writing child cannot starve the timeout.
    for _ in 0..128 {
        match file.read(&mut buffer) {
            Ok(0) => break,
            Ok(n) => {
                if out.len() + n > 1024 * 1024 {
                    bail!("helper output exceeds 1 MiB");
                }
                out.extend_from_slice(&buffer[..n]);
            }
            Err(e) if e.kind() == ErrorKind::WouldBlock => break,
            Err(e) if e.kind() == ErrorKind::Interrupted => continue,
            Err(e) => return Err(e.into()),
        }
    }
    Ok(())
}

pub fn run(
    program: &Path,
    args: &[&str],
    timeout: Duration,
    allow_cleanup: bool,
) -> Result<String> {
    let mut command = Command::new(program);
    command.args(args).env("LC_ALL", "C");
    run_configured(command, timeout, allow_cleanup, false)
}

/// Profile adapters need a controlled cwd/environment and must retire descendants
/// even after their launcher exits successfully. They share the bounded runner.
pub fn run_configured(
    mut command: Command,
    timeout: Duration,
    allow_cleanup: bool,
    retire_descendants: bool,
) -> Result<String> {
    if !allow_cleanup && INTERRUPTED.load(Ordering::Relaxed) {
        bail!("interrupted before helper launch");
    }
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .process_group(0)
        .spawn()
        .with_context(|| format!("execute {:?}", command.get_program()))?;
    let result = (|| {
        let mut stdout = nonblocking(child.stdout.take().unwrap().into_raw_fd())?;
        let mut stderr = nonblocking(child.stderr.take().unwrap().into_raw_fd())?;
        let mut out = Vec::new();
        let mut err = Vec::new();
        let start = Instant::now();
        loop {
            drain(&mut stdout, &mut out)?;
            drain(&mut stderr, &mut err)?;
            if let Some(status) = child.try_wait()? {
                drain(&mut stdout, &mut out)?;
                drain(&mut stderr, &mut err)?;
                if !status.success() {
                    bail!(
                        "helper exited {status}: {}",
                        String::from_utf8_lossy(&err[..err.len().min(4096)])
                    );
                }
                return String::from_utf8(out).context("helper output is not UTF-8");
            }
            if start.elapsed() >= timeout {
                bail!("helper timed out after {} ms", timeout.as_millis());
            }
            if !allow_cleanup && INTERRUPTED.load(Ordering::Relaxed) {
                bail!("interrupted");
            }
            std::thread::sleep(Duration::from_millis(2));
        }
    })();
    if result.is_err() || retire_descendants {
        // SAFETY: child created a new process group whose id is its PID. Never target
        // the observed application, its service, or a process found by name.
        unsafe {
            libc::kill(-(child.id() as i32), libc::SIGKILL);
        }
        let _ = child.wait();
    }
    result
}

pub fn resolve(program: &Path) -> Result<std::path::PathBuf> {
    // Preserve the final symlink/argv[0] spelling: coreutils/busybox (and some
    // wrappers) select behavior from the invoked basename. Canonicalizing it
    // before exec silently changes the command being run.
    if program.components().count() > 1 {
        let path = if program.is_absolute() {
            program.to_path_buf()
        } else {
            std::env::current_dir()?.join(program)
        };
        if path.is_file() {
            return Ok(path);
        }
        bail!("{} is not a file", path.display());
    }
    for dir in std::env::split_paths(&std::env::var_os("PATH").unwrap_or_default()) {
        let path = dir.join(program);
        if path.is_file() {
            return Ok(if path.is_absolute() {
                path
            } else {
                std::env::current_dir()?.join(path)
            });
        }
    }
    bail!("{} not found in PATH", program.display())
}
