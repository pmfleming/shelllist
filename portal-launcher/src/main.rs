//! Frontend-owned browser/focus effects. No network identity, fallback or retry policy.
use anyhow::{Context, Result, ensure};
use serde::Deserialize;
use shelllist_hyprland::Client;
use std::{
    fs::File,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

const CLASS: &str = "shelllist-captive-portal";
#[derive(Debug)]
struct Intent {
    url: String,
    workspace: String,
    expires_at_ms: u64,
}
impl Intent {
    fn parse(args: impl IntoIterator<Item = String>) -> Result<Self> {
        let mut args = args.into_iter();
        let mut url = None;
        let mut workspace = None;
        let mut expires = None;
        while let Some(key) = args.next() {
            let value = args.next().context("missing argument value")?;
            match key.as_str() {
                "--url" if url.is_none() => url = Some(value),
                "--workspace" if workspace.is_none() => workspace = Some(value),
                "--expires-at-ms" if expires.is_none() => expires = Some(value.parse::<u64>()?),
                _ => anyhow::bail!("unknown or repeated argument"),
            }
        }
        let url = url.context("missing URL")?;
        ensure!(
            url.len() <= 4096
                && !url
                    .chars()
                    .any(|c| c.is_control() || c.is_whitespace() || c == '\\'),
            "unsafe URL"
        );
        let parsed = url::Url::parse(&url)?;
        ensure!(
            (url.starts_with("http://") || url.starts_with("https://"))
                && parsed.host_str().is_some()
                && parsed.username().is_empty()
                && parsed.password().is_none(),
            "expected credential-free HTTP(S) URL"
        );
        let workspace = workspace.unwrap_or_default();
        ensure!(
            workspace.len() <= 128
                && workspace
                    .chars()
                    .all(|c| c.is_ascii_alphanumeric() || "_.:+-".contains(c)),
            "unsafe workspace"
        );
        Ok(Self {
            url,
            workspace,
            expires_at_ms: expires.context("missing deadline")?,
        })
    }
    fn fresh(&self) -> Result<()> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_millis();
        ensure!(
            now < u128::from(self.expires_at_ms),
            "portal intent expired"
        );
        Ok(())
    }
}

#[derive(Debug, Deserialize)]
struct Window {
    address: String,
    #[serde(default)]
    class: String,
    #[serde(default, rename = "initialClass")]
    initial_class: String,
}
impl Window {
    fn portal(&self) -> bool {
        self.class == CLASS || self.initial_class == CLASS
    }
    fn safe_address(&self) -> bool {
        self.address.strip_prefix("0x").is_some_and(|value| {
            !value.is_empty() && value.len() <= 32 && value.chars().all(|c| c.is_ascii_hexdigit())
        })
    }
}
async fn windows(client: &Client) -> Result<Vec<Window>> {
    Ok(
        serde_json::from_str::<Vec<Window>>(&client.request("j/clients").await?)?
            .into_iter()
            .filter(|w| w.portal() && w.safe_address())
            .collect(),
    )
}
async fn dispatch(client: &Client, lua: String, legacy: String) -> Result<()> {
    if client
        .request(&format!("dispatch {lua}"))
        .await
        .is_ok_and(|reply| reply.trim() == "ok")
    {
        return Ok(());
    }
    ensure!(
        client.request(&format!("dispatch {legacy}")).await?.trim() == "ok",
        "compositor rejected focus command"
    );
    Ok(())
}
async fn focus(client: &Client, window: &Window, workspace: &str) -> Result<()> {
    ensure!(window.safe_address(), "invalid compositor address");
    if !workspace.is_empty() {
        dispatch(client, format!("hl.dsp.window.move({{ workspace = '{workspace}', follow = false, window = 'address:{}' }})", window.address), format!("movetoworkspacesilent {workspace},address:{}", window.address)).await?;
    }
    dispatch(
        client,
        format!("hl.dsp.focus({{ window = 'address:{}' }})", window.address),
        format!("focuswindow address:{}", window.address),
    )
    .await
}
fn profile_and_lock() -> Result<(PathBuf, File)> {
    use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt, PermissionsExt};
    let runtime =
        PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR required")?);
    ensure!(runtime.is_absolute(), "runtime directory must be absolute");
    let root = runtime.join("shelllist-captive-portal");
    match std::fs::DirBuilder::new().mode(0o700).create(&root) {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
        Err(e) => return Err(e.into()),
    }
    let metadata = std::fs::symlink_metadata(&root)?;
    ensure!(
        metadata.is_dir() && metadata.uid() == rustix::process::geteuid().as_raw(),
        "unsafe browser state directory"
    );
    // The retired shell helper used umask permissions. Tighten only our own directory.
    std::fs::set_permissions(&root, std::fs::Permissions::from_mode(0o700))?;
    let lock = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .custom_flags((rustix::fs::OFlags::NOFOLLOW | rustix::fs::OFlags::NONBLOCK).bits() as i32)
        .open(root.join("lock"))?;
    ensure!(lock.metadata()?.is_file(), "unsafe browser lock");
    rustix::fs::flock(&lock, rustix::fs::FlockOperation::NonBlockingLockExclusive)
        .context("portal browser helper busy")?;
    let profile = root.join("browser-profile");
    match std::fs::DirBuilder::new().mode(0o700).create(&profile) {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
        Err(e) => return Err(e.into()),
    }
    let metadata = std::fs::symlink_metadata(&profile)?;
    ensure!(
        metadata.is_dir() && metadata.uid() == rustix::process::geteuid().as_raw(),
        "unsafe browser profile"
    );
    Ok((profile, lock))
}
fn browser_command(browser: &Path, profile: &Path, url: &str) -> Command {
    let mut command = Command::new(browser);
    command.arg(format!("--user-data-dir={}", profile.display())).arg(format!("--class={CLASS}"))
        .args(["--ozone-platform=x11", "--no-first-run", "--no-default-browser-check", "--disable-search-engine-choice-screen", "--new-window", "--disable-extensions", "--disable-background-mode", "--disable-quic", "--no-proxy-server", "--disable-features=HttpsUpgrades,HttpsFirstBalancedModeAutoEnable,HttpsFirstModeV2,DnsOverHttpsUpgrade"])
        .arg(format!("--app={url}")).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null());
    command
}
fn find_browser() -> Result<PathBuf> {
    use std::os::unix::fs::PermissionsExt;
    let paths = std::env::var_os("PATH").unwrap_or_default();
    for name in ["google-chrome-stable", "google-chrome", "chromium"] {
        for path in std::env::split_paths(&paths) {
            let candidate = path.join(name);
            if std::fs::metadata(&candidate)
                .is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
            {
                return Ok(candidate);
            }
        }
    }
    anyhow::bail!("no supported browser found")
}
async fn launch(intent: Intent, effect_started: &mut bool) -> Result<()> {
    intent.fresh()?;
    let (profile, _lock) = profile_and_lock()?;
    let browser = find_browser()?;
    let client = Client::from_environment();
    let before = windows(&client).await?;
    let workspace = if intent.workspace.is_empty() {
        #[derive(Deserialize)]
        struct Workspace {
            id: i64,
        }
        serde_json::from_str::<Workspace>(&client.request("j/activeworkspace").await?)?
            .id
            .to_string()
    } else {
        intent.workspace.clone()
    };
    intent.fresh()?;
    // Every explicit intent submits its URL, including when a portal window already
    // exists. Merely focusing the old page would defeat manual fallback requests.
    let mut child = browser_command(&browser, &profile, &intent.url)
        .spawn()
        .context("start browser")?;
    *effect_started = true;
    let observe = async {
        loop {
            if let Some(window) = windows(&client)
                .await?
                .into_iter()
                .find(|w| !before.iter().any(|old| old.address == w.address))
            {
                return focus(&client, &window, &workspace).await;
            }
            if let Some(status) = child.try_wait()? {
                ensure!(status.success(), "browser exited unsuccessfully");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    };
    tokio::time::timeout(Duration::from_secs(8), observe)
        .await
        .context("browser window not observed; launch outcome uncertain")?
}
#[tokio::main(flavor = "current_thread")]
async fn main() {
    let mut started = false;
    let result = match Intent::parse(std::env::args().skip(1)) {
        Ok(intent) => launch(intent, &mut started).await,
        Err(error) => Err(error),
    };
    let outcome = if result.is_ok() {
        "opened"
    } else if started {
        "uncertain"
    } else {
        "failed"
    };
    if let Err(error) = result {
        eprintln!("portal launch: {error:#}");
    }
    println!("{}", serde_json::json!({"outcome":outcome}));
}

#[cfg(test)]
mod tests {
    use super::*;
    fn parse(url: &str, workspace: &str) -> Result<Intent> {
        Intent::parse(
            [
                "--url",
                url,
                "--workspace",
                workspace,
                "--expires-at-ms",
                "0",
            ]
            .map(String::from),
        )
    }
    #[test]
    fn only_url_deadline_and_ui_workspace_are_accepted() {
        let intent = parse("http://example.org/path?a=b&c=d", "name:portal").unwrap();
        assert!(intent.fresh().is_err());
        for url in [
            "javascript:alert(1)",
            "file:///tmp/a",
            "http://u:p@host",
            "http://a\\b",
            "http://a/\n",
        ] {
            assert!(parse(url, "1").is_err());
        }
        assert!(parse("http://a/", "1';exec x").is_err());
        assert!(Intent::parse(["--episode", "fake"].map(String::from)).is_err());
    }
    #[test]
    fn browser_arguments_are_literal_not_shell_code() {
        let url = "http://example.org/?q=$(touch%20/tmp/pwn)&x=1";
        let command = browser_command(Path::new("browser"), Path::new("/runtime/profile"), url);
        assert_eq!(
            command.get_args().last().unwrap(),
            format!("--app={url}").as_str()
        );
        assert!(!command.get_args().any(|arg| arg == "-c"));
    }
    #[tokio::test]
    async fn workspace_and_focus_use_native_ipc_with_legacy_dispatch_fallback() {
        use tokio::io::{AsyncReadExt, AsyncWriteExt};
        let root = std::env::temp_dir().join(format!(
            "portal-ipc-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let instance = root.join("hypr/test");
        std::fs::create_dir_all(&instance).unwrap();
        let socket = tokio::net::UnixListener::bind(instance.join(".socket.sock")).unwrap();
        let client = Client::new(root.clone(), Some("test".into()));
        let server = tokio::spawn(async move {
            for (expected, reply) in [
                (
                    "j/clients",
                    r#"[{"address":"0x123","class":"shelllist-captive-portal"}]"#,
                ),
                (
                    "dispatch hl.dsp.window.move({ workspace = '3', follow = false, window = 'address:0x123' })",
                    "unknown dispatcher",
                ),
                ("dispatch movetoworkspacesilent 3,address:0x123", "ok"),
                ("dispatch hl.dsp.focus({ window = 'address:0x123' })", "ok"),
            ] {
                let (mut stream, _) = socket.accept().await.unwrap();
                let mut command = String::new();
                stream.read_to_string(&mut command).await.unwrap();
                assert_eq!(command, expected);
                stream.write_all(reply.as_bytes()).await.unwrap();
            }
        });
        let windows = windows(&client).await.unwrap();
        focus(&client, &windows[0], "3").await.unwrap();
        server.await.unwrap();
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn native_client_parsing_filters_class_and_untrusted_addresses() {
        let values: Vec<Window> = serde_json::from_str(r#"[{"address":"0x123","class":"shelllist-captive-portal"},{"address":"0x1'; exec x","initialClass":"shelllist-captive-portal"},{"address":"0x456","class":"other"}]"#).unwrap();
        assert_eq!(
            values
                .iter()
                .filter(|w| w.portal() && w.safe_address())
                .count(),
            1
        );
    }
}
