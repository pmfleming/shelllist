//! Frontend/producer parity. Payload type assertions live in each producer's
//! `frontend_contract` Rust tests against its own serde DTOs, never mirror structs.
use anyhow::{Context, Result, ensure};
use serde_json::Value;
use std::{collections::BTreeSet, fs, path::Path, process::Command};
pub fn test_and_build(repo: &Path, daemon: &str, nix: bool) -> Result<std::path::PathBuf> {
    let cargo = || {
        let mut command = if nix {
            let mut command = Command::new("nix");
            command
                .args(["develop", "--no-write-lock-file"])
                .arg(repo)
                .args(["--command", "cargo"]);
            command
        } else {
            Command::new("cargo")
        };
        command.current_dir(repo);
        command
    };
    super::run(cargo().args(["test", "--locked", "--lib", "contract"]))?;
    // Ask Cargo for the actual executable, honoring target-dir/profile/config.
    let name = format!("{daemon}-daemon");
    let output = cargo()
        .args([
            "build",
            "--locked",
            "--bin",
            &name,
            "--message-format=json-render-diagnostics",
        ])
        .output()?;
    use std::io::Write;
    std::io::stderr().write_all(&output.stderr)?;
    ensure!(output.status.success(), "{name} build failed");
    let mut binary = None;
    for line in output
        .stdout
        .split(|b| *b == b'\n')
        .filter(|line| !line.is_empty())
    {
        let artifact: Value = serde_json::from_slice(line)?;
        if artifact["reason"] == "compiler-artifact"
            && artifact["target"]["name"] == name
            && let Some(path) = artifact["executable"].as_str()
        {
            binary = Some(path.into());
        }
    }
    binary.context("Cargo did not report the producer executable")
}
fn output(bin: &Path, daemon: &str, command: &str) -> Result<Value> {
    let mut process = Command::new(bin);
    // NM enforces 0600 on its log. Never point it at /dev/null or a shared file.
    let temporary = tempfile::tempdir()?;
    if daemon == "nm" {
        process
            .arg("--log-file")
            .arg(temporary.path().join("nm.log"));
    }
    let output = process
        .args(["debug", command])
        .output()
        .with_context(|| format!("{} debug {command}", bin.display()))?;
    ensure!(
        output.status.success(),
        "{daemon} debug {command} failed ({}): {}",
        output.status,
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(serde_json::from_slice(&output.stdout)?)
}
fn names(registry: &Value) -> Result<BTreeSet<String>> {
    let mut names = BTreeSet::new();
    for kind in ["methods", "streams"] {
        for entry in registry[kind]
            .as_array()
            .context("missing registry entries")?
        {
            ensure!(
                names.insert(
                    entry["name"]
                        .as_str()
                        .context("missing entry name")?
                        .to_owned()
                ) || kind == "streams",
                "duplicate method"
            );
        }
    }
    Ok(names)
}
fn coverage(registry: &Value, text: &str, all: bool, prefixes: &[&str]) -> Result<()> {
    let entries = names(registry)?;
    let literals = regex::Regex::new(r#""([A-Za-z][A-Za-z0-9.-]*)""#)?
        .captures_iter(text)
        .map(|c| c[1].to_owned())
        .collect::<BTreeSet<_>>();
    if all {
        ensure!(
            entries.is_subset(&literals),
            "frontend omits registry entries: {:?}",
            entries.difference(&literals).collect::<Vec<_>>()
        );
    } else {
        for name in &literals {
            if prefixes
                .iter()
                .any(|prefix| name.starts_with(&format!("{prefix}.")))
            {
                ensure!(
                    entries.contains(name),
                    "frontend declares unknown protocol entry {name}"
                );
            }
        }
    }
    Ok(())
}
fn nm_api(registry: &Value) -> Result<String> {
    let methods = [
        "wifi.status",
        "wifi.setEnabled",
        "wifi.networks",
        "wifi.band.status",
        "wifi.band.set",
        "wifi.scan",
        "wifi.connectTarget",
        "wifi.disconnect",
        "wifi.profile.operation",
        "wifi.secret.provide",
        "wifi.qr.parse",
        "wifi.qr.render",
        "wifi.qr.connect",
        "network.portalPrepare",
        "network.portalClaim",
        "network.portalComplete",
        "network.inventory",
        "network.status",
        "network.activateProfile",
        "network.deactivate",
        "network.statistics.watch",
        "hotspot.capabilities",
        "hotspot.status",
        "hotspot.start",
        "hotspot.stop",
        "vpn.list",
        "vpn.status",
        "vpn.connect",
        "vpn.disconnect",
        "operation.status",
    ];
    let base = [
        "wifi.status",
        "network.connectivity",
        "wifi.networks",
        "wifi.scan",
        "wifi.connect",
        "wifi.band",
        "wifi.secret",
        "network.health",
    ];
    let demand = ["network.inventory", "network.statistics", "hotspot", "vpn"];
    let entries = |kind: &str| -> Result<Vec<&str>> {
        registry[kind]
            .as_array()
            .context("registry array")?
            .iter()
            .filter(|v| kind == "methods" || v["subscribable"] == true)
            .map(|v| v["name"].as_str().context("registry name"))
            .collect()
    };
    let identifier = |s: &str| s.replace(['.', '-'], "_");
    let method_entries = entries("methods")?;
    let streams = entries("streams")?;
    ensure!(
        methods.iter().all(|m| method_entries.contains(m))
            && base.iter().chain(&demand).all(|s| streams.contains(s)),
        "NM frontend method/stream missing"
    );
    let mappings = |names: Vec<&str>, kind: &str| {
        names
            .into_iter()
            .map(|name| format!("    {}: Protocol.{kind}[\"{name}\"]", identifier(name)))
            .collect::<Vec<_>>()
            .join(",\n")
    };
    let list = |selected: &[&str]| {
        streams
            .iter()
            .filter(|name| selected.contains(name))
            .map(|name| format!("    streams.{}", identifier(name)))
            .collect::<Vec<_>>()
            .join(",\n")
    };
    Ok(format!(
        ".pragma library\n.import \"NmProtocol.generated.js\" as Protocol\n\nvar protocol = Protocol.protocol;\nvar version = Protocol.version;\n\nvar methods = {{\n{}\n}};\n\nvar streams = {{\n{}\n}};\n\nvar subscribedStreams = [\n{}\n];\n\n// Streams tied to an operation the shell starts on demand. Subscribing to\n// them by default would make the daemon compute payloads nobody is reading.\nvar onDemandStreams = [\n{}\n];\n",
        mappings(
            method_entries
                .into_iter()
                .filter(|n| methods.contains(n))
                .collect(),
            "methods"
        ),
        mappings(streams.clone(), "streams"),
        list(&base),
        list(&demand)
    ))
}
pub fn check(root: &Path, daemon: &str, bin: &Path) -> Result<()> {
    ensure!(
        ["app", "bar", "bt", "clip", "nm"].contains(&daemon),
        "unknown producer {daemon}"
    );
    let expected: Value = serde_json::from_slice(&fs::read(
        root.join(format!("contracts/{daemon}-api-ui-contract.fixture.json")),
    )?)?;
    ensure!(
        output(bin, daemon, "contract-fixture")? == expected,
        "{daemon} frontend fixture differs from producer (refresh producer fixtures)"
    );
    let raw = output(bin, daemon, "protocol-registry")?;
    let registry = if daemon == "nm" {
        &raw["data"]["protocol"]
    } else {
        &raw
    };
    match daemon {
        "nm" => ensure!(
            fs::read_to_string(root.join("wifi/NmApi.js"))? == nm_api(registry)?,
            "NM frontend registry/subscription policy drift"
        ),
        "app" | "clip" => {
            let path = if daemon == "app" {
                "launcher/AppApi.js"
            } else {
                "clipboard/ClipApi.js"
            };
            coverage(registry, &fs::read_to_string(root.join(path))?, true, &[])?;
        }
        "bt" => coverage(
            registry,
            &fs::read_to_string(root.join("bluetooth/BtApi.js"))?,
            false,
            &["bluetooth", "pairing"],
        )?,
        "bar" => {
            let mut text = String::new();
            for path in [
                "bar/BarApi.js",
                "activity/ActivityApi.js",
                "battery/BatteryApi.js",
                "displays/DisplayApi.js",
            ] {
                text.push_str(&fs::read_to_string(root.join(path))?);
            }
            coverage(
                registry,
                &text,
                false,
                &[
                    "bar",
                    "activity",
                    "locations",
                    "location",
                    "todos",
                    "workspace",
                    "media",
                    "audio",
                    "brightness",
                    "battery",
                    "powerProfile",
                    "powerSleep",
                    "displayPolicy",
                    "displayLayout",
                    "displayFocus",
                    "display-policy",
                    "power-profile",
                    "power-sleep",
                    "sleep-policy",
                    "osd-hardware",
                    "notifications",
                    "updates",
                    "timezone",
                ],
            )?;
        }
        _ => unreachable!(),
    }
    if daemon == "app" {
        let fixture: Value = serde_json::from_slice(&fs::read(
            root.join("contracts/app-resource-ui-contract.fixture.json"),
        )?)?;
        ensure!(
            output(bin, daemon, "resource-contract-fixture")? == fixture,
            "app resource contract drift"
        );
    }
    println!("{daemon}: checked fixture and frontend registry match");
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn nm_log_is_private_temporary_and_cleaned_up() {
        use std::os::unix::fs::PermissionsExt;
        let directory = tempfile::tempdir().unwrap();
        let script = directory.path().join("producer");
        let path = std::env::var_os("PATH").unwrap();
        let shell = std::env::split_paths(&path)
            .map(|p| p.join("sh"))
            .find(|p| p.is_file())
            .unwrap();
        fs::write(&script,format!("#!{}\nprintf %s \"$2\" > \"$0.args\"\nprintf test > \"$2\"\nprintf '{{\"ok\":true}}'\n",shell.display())).unwrap();
        fs::set_permissions(&script, fs::Permissions::from_mode(0o700)).unwrap();
        assert_eq!(
            output(&script, "nm", "contract-fixture").unwrap(),
            json!({"ok":true})
        );
        let log = std::path::PathBuf::from(
            fs::read_to_string(directory.path().join("producer.args")).unwrap(),
        );
        assert_eq!(log.file_name().unwrap(), "nm.log");
        assert!(!log.exists());
        assert!(!log.parent().unwrap().exists());
    }
    #[test]
    fn registry_coverage_catches_omissions_and_unknown_calls() {
        let registry =
            json!({"methods":[{"name":"test.read"}],"streams":[{"name":"test.changed"}]});
        assert!(coverage(&registry, "\"test.read\"", true, &[]).is_err());
        assert!(coverage(&registry, "\"test.unknown\"", false, &["test"]).is_err());
        coverage(&registry, "\"test.read\" \"test.changed\"", true, &[]).unwrap();
        assert!(nm_api(&registry).is_err());
    }
}
