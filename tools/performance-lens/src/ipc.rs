use crate::{command, model::Identity, procfs};
use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use std::{
    path::{Path, PathBuf},
    time::Duration,
};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Instance {
    pub pid: u32,
    pub id: String,
    pub config_path: PathBuf,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Status {
    pub visible: bool,
    pub surface: String,
    pub opened: std::collections::BTreeMap<String, bool>,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Content {
    pub surface: String,
    pub latency_ms: f64,
    pub warm: bool,
    pub recorded_at_ms: f64,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Trace {
    pub schema_version: u32,
    pub surface: String,
    pub open_requested_at_ms: f64,
    pub first_frame_at_ms: f64,
    pub open_to_first_frame_ms: f64,
    pub content: Content,
    // Latest controller values intentionally NOT imported as current action metrics.
}

pub trait Endpoint {
    fn call(&self, method: &str, args: &[&str], timeout: Duration, cleanup: bool)
    -> Result<String>;
    fn status(&self, timeout: Duration, cleanup: bool) -> Result<Status> {
        serde_json::from_str(&self.call("status", &[], timeout, cleanup)?)
            .context("invalid status JSON")
    }
    fn trace(&self, timeout: Duration, cleanup: bool) -> Result<Trace> {
        let t: Trace = serde_json::from_str(&self.call("responsiveness", &[], timeout, cleanup)?)
            .context("invalid timing JSON")?;
        ensure!(t.schema_version == 1, "unsupported timing schema");
        Ok(t)
    }
}

pub struct Ipc {
    pub program: PathBuf,
    pub identity: Identity,
    pub instance: Instance,
}
impl Ipc {
    pub fn connect(program: &Path, identity: &Identity) -> Result<Self> {
        let program = command::resolve(program)?;
        let help = command::run(&program, &["ipc", "--help"], Duration::from_secs(2), false)?;
        ensure!(
            help.contains("--pid"),
            "installed Quickshell lacks explicit PID IPC routing"
        );
        let instances: Vec<Instance> = serde_json::from_str(&command::run(
            &program,
            &["list", "--all", "--json"],
            Duration::from_secs(2),
            false,
        )?)?;
        let matching: Vec<_> = instances
            .into_iter()
            .filter(|i| i.pid == identity.pid)
            .collect();
        ensure!(
            matching.len() == 1,
            "PID must identify exactly one live Quickshell instance"
        );
        procfs::verify(identity)?;
        let ipc = Self {
            program,
            identity: identity.clone(),
            instance: matching[0].clone(),
        };
        ensure!(
            ipc.call("ping", &[], Duration::from_secs(2), false)?.trim() == "pong",
            "not a Shelllist IPC endpoint"
        );
        Ok(ipc)
    }
}
impl Endpoint for Ipc {
    fn call(
        &self,
        method: &str,
        args: &[&str],
        timeout: Duration,
        cleanup: bool,
    ) -> Result<String> {
        ensure!(
            [
                "ping",
                "status",
                "listSurfaces",
                "responsiveness",
                "open",
                "hide"
            ]
            .contains(&method),
            "forbidden IPC method"
        );
        procfs::verify(&self.identity)?;
        let pid = self.identity.pid.to_string();
        let mut argv = vec!["ipc", "--pid", &pid, "call", "shelllist", method];
        argv.extend(args);
        let output = command::run(&self.program, &argv, timeout, cleanup)?;
        procfs::verify(&self.identity)?;
        Ok(output.trim().into())
    }
}

/// Returns true only for a fresh, scoped complete pair of endpoints.
/// A still-pending trace returns false; contradictory/new unrelated data fails closed.
pub fn validate_trace(
    before: &Trace,
    now: &Trace,
    surface: &str,
    window: (f64, f64),
    owned: &mut Option<f64>,
    warm: bool,
) -> Result<bool> {
    ensure!(now.schema_version == 1, "unsupported trace schema");
    if now.open_requested_at_ms <= before.open_requested_at_ms {
        return Ok(false);
    }
    ensure!(now.surface == surface, "surface changed during trial");
    ensure!(
        now.open_requested_at_ms >= window.0 - 2.0 && now.open_requested_at_ms <= window.1 + 2.0,
        "open timestamp outside command window"
    );
    match *owned {
        Some(request) => ensure!(
            request == now.open_requested_at_ms,
            "another open replaced the owned request"
        ),
        None => *owned = Some(now.open_requested_at_ms),
    }
    if now.first_frame_at_ms == 0.0 || now.open_to_first_frame_ms < 0.0 {
        return Ok(false);
    }
    ensure!(
        now.first_frame_at_ms >= now.open_requested_at_ms,
        "frame predates request"
    );
    ensure!(
        (now.first_frame_at_ms - now.open_requested_at_ms - now.open_to_first_frame_ms).abs()
            <= 1.0,
        "inconsistent frame interval"
    );
    if now.content.recorded_at_ms <= before.content.recorded_at_ms || now.content.surface != surface
    {
        return Ok(false);
    }
    ensure!(
        now.content.recorded_at_ms >= window.0 - 2.0,
        "content record predates command"
    );
    if now.content.latency_ms < 0.0 {
        return Ok(false);
    }
    if warm {
        ensure!(now.content.warm, "expected already-loaded warm content");
    }
    Ok(true)
}

pub fn safe_hide(endpoint: &impl Endpoint, surface: &str, request: Option<f64>) -> Result<()> {
    let status = endpoint.status(Duration::from_secs(1), true)?;
    if !status.visible {
        return Ok(());
    }
    let trace = endpoint.trace(Duration::from_secs(1), true)?;
    if status.surface != surface
        || trace.surface != surface
        || request != Some(trace.open_requested_at_ms)
    {
        bail!("cleanup refused: visible surface/request ownership is ambiguous; left UI untouched");
    }
    endpoint.call("hide", &[], Duration::from_secs(1), true)?;
    ensure!(
        !endpoint.status(Duration::from_secs(1), true)?.visible,
        "surface did not hide"
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn trace() -> Trace {
        Trace {
            schema_version: 1,
            surface: "applications".into(),
            open_requested_at_ms: 100.0,
            first_frame_at_ms: 110.0,
            open_to_first_frame_ms: 10.0,
            content: Content {
                surface: "applications".into(),
                latency_ms: 0.0,
                warm: true,
                recorded_at_ms: 100.0,
            },
        }
    }
    #[test]
    fn stale_pending_wrong_surface_and_replaced_request() {
        let old = trace();
        let mut now = trace();
        let mut owned = None;
        assert!(
            !validate_trace(&old, &now, "applications", (200.0, 210.0), &mut owned, true).unwrap()
        );
        now.open_requested_at_ms = 205.0;
        now.first_frame_at_ms = 215.0;
        now.content.recorded_at_ms = 204.0;
        assert!(
            validate_trace(&old, &now, "applications", (200.0, 210.0), &mut owned, true).unwrap()
        );
        now.first_frame_at_ms = 0.0;
        assert!(
            !validate_trace(&old, &now, "applications", (200.0, 210.0), &mut owned, true).unwrap()
        );
        now.open_requested_at_ms = 206.0;
        assert!(
            validate_trace(&old, &now, "applications", (200.0, 210.0), &mut owned, true).is_err()
        );
        now.surface = "wifi".into();
        assert!(
            validate_trace(&old, &now, "applications", (200.0, 210.0), &mut None, true).is_err()
        );
    }
    #[test]
    fn frame_and_content_must_both_be_fresh() {
        let old = trace();
        let mut now = trace();
        now.open_requested_at_ms = 200.0;
        now.first_frame_at_ms = 210.0;
        assert!(
            !validate_trace(&old, &now, "applications", (199.0, 201.0), &mut None, true).unwrap()
        );
        now.content.recorded_at_ms = 200.0;
        now.content.warm = false;
        assert!(
            validate_trace(&old, &now, "applications", (199.0, 201.0), &mut None, true).is_err()
        );
        assert!(
            validate_trace(&old, &now, "applications", (199.0, 201.0), &mut None, false).unwrap()
        );
        now.first_frame_at_ms = 199.0;
        assert!(
            validate_trace(&old, &now, "applications", (199.0, 201.0), &mut None, false).is_err()
        );
    }
}
