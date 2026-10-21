use crate::{
    command::INTERRUPTED,
    ipc::{self, Endpoint},
    model::Event,
    sampler::Control,
};
use anyhow::{Result, bail, ensure};
use serde_json::json;
use std::{
    io::Write,
    sync::atomic::Ordering,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

pub fn unix_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}
pub fn sleep(duration: Duration) -> Result<()> {
    let until = Instant::now() + duration;
    while Instant::now() < until {
        ensure!(!INTERRUPTED.load(Ordering::Relaxed), "interrupted");
        std::thread::sleep(
            until
                .saturating_duration_since(Instant::now())
                .min(Duration::from_millis(10)),
        );
    }
    Ok(())
}

pub fn event(
    file: &mut impl Write,
    start: Instant,
    trial: u32,
    phase: &str,
    kind: &str,
    data: serde_json::Value,
) -> Result<()> {
    let mut bytes = serde_json::to_vec(&Event {
        elapsed_s: start.elapsed().as_secs_f64(),
        trial,
        phase: phase.into(),
        kind: kind.into(),
        data,
    })?;
    bytes.push(b'\n');
    file.write_all(&bytes)?;
    file.flush()?;
    Ok(())
}

pub struct WarmOptions<'a> {
    pub surface: &'a str,
    pub trials: u32,
    pub timeout: Duration,
    pub poll: Duration,
    pub settle: Duration,
}

pub fn preflight(endpoint: &impl Endpoint, surface: &str) -> Result<()> {
    ensure!(
        !endpoint.status(Duration::from_secs(2), false)?.visible,
        "refusing to benchmark a visible panel: close/discard drafts yourself first"
    );
    let catalog: serde_json::Value = serde_json::from_str(&endpoint.call(
        "listSurfaces",
        &[],
        Duration::from_secs(2),
        false,
    )?)?;
    ensure!(
        catalog
            .as_array()
            .is_some_and(|rows| rows.iter().any(|r| r["id"].as_str() == Some(surface))),
        "unknown surface {surface}"
    );
    Ok(())
}

pub fn warm_open(
    endpoint: &impl Endpoint,
    file: &mut impl Write,
    start: Instant,
    control: &Control,
    options: &WarmOptions<'_>,
) -> Result<()> {
    preflight(endpoint, options.surface)?;
    for trial in 0..=options.trials {
        ensure!(
            !control.stop.load(Ordering::Relaxed),
            "sampler stopped; aborting UI sequence"
        );
        let phase = if trial == 0 { "warmup" } else { "warm-open" };
        ensure!(
            !endpoint.status(Duration::from_secs(1), false)?.visible,
            "UI changed between trials; aborting without hiding it"
        );
        let before = endpoint.trace(Duration::from_secs(1), false)?;
        control.phase(phase);
        event(
            file,
            start,
            trial,
            phase,
            "trial_started",
            json!({"before":before,"timeout_ms":options.timeout.as_millis(),"surface":options.surface}),
        )?;
        let mut owned = None;
        let mut ack = None;
        let mut completed = None;
        let outcome = (|| -> Result<()> {
            ensure!(
                !control.stop.load(Ordering::Relaxed),
                "sampler stopped before open"
            );
            let wall_start = unix_ms();
            let monotonic = Instant::now();
            let reply = endpoint.call("open", &[options.surface], options.timeout, false)?;
            let ack_ms = monotonic.elapsed().as_secs_f64() * 1000.0;
            let wall_end = unix_ms();
            ensure!(reply == "ok", "open rejected: {reply}");
            ack = Some(ack_ms);
            ensure!(
                clock_consistent(wall_start, wall_end, ack_ms),
                "wall clock changed during command"
            );
            event(
                file,
                start,
                trial,
                phase,
                "acknowledged",
                json!({"ack_ms":ack_ms,"wall_start_ms":wall_start,"wall_end_ms":wall_end}),
            )?;
            loop {
                ensure!(
                    !control.stop.load(Ordering::Relaxed),
                    "sampler stopped during trial"
                );
                ensure!(!INTERRUPTED.load(Ordering::Relaxed), "interrupted");
                let remaining = options
                    .timeout
                    .checked_sub(monotonic.elapsed())
                    .filter(|d| !d.is_zero())
                    .ok_or_else(|| {
                        anyhow::anyhow!(
                            "trial timeout (right-censored at {} ms)",
                            options.timeout.as_millis()
                        )
                    })?;
                let trace = endpoint.trace(remaining.min(Duration::from_secs(1)), false)?;
                event(
                    file,
                    start,
                    trial,
                    phase,
                    "observation",
                    json!({"trace":trace}),
                )?;
                ensure!(
                    clock_consistent(
                        wall_start,
                        unix_ms(),
                        monotonic.elapsed().as_secs_f64() * 1000.0
                    ),
                    "wall clock discontinuity during trial"
                );
                ensure!(
                    trace.first_frame_at_ms <= unix_ms() as f64 + 2.0
                        && trace.content.recorded_at_ms <= unix_ms() as f64 + 2.0,
                    "future timing endpoints"
                );
                let ready = ipc::validate_trace(
                    &before,
                    &trace,
                    options.surface,
                    (wall_start as f64, wall_end as f64),
                    &mut owned,
                    trial > 0,
                )?;
                if ready {
                    let status = endpoint.status(
                        options
                            .timeout
                            .saturating_sub(monotonic.elapsed())
                            .max(Duration::from_millis(1)),
                        false,
                    )?;
                    ensure!(
                        status.visible && status.surface == options.surface,
                        "UI visibility/surface changed during trial"
                    );
                    ensure!(monotonic.elapsed() <= options.timeout, "trial timeout");
                    completed = Some(trace);
                    break;
                }
                sleep(
                    options
                        .poll
                        .min(options.timeout.saturating_sub(monotonic.elapsed())),
                )?;
            }
            Ok(())
        })();
        // Do not infer ownership when open timed out or a new request could not be observed.
        // In that case an open panel is deliberately left alone with a diagnostic.
        let cleanup = ipc::safe_hide(endpoint, options.surface, owned);
        let mut errors = Vec::new();
        if let Err(e) = outcome {
            errors.push(format!("{e:#}"));
        }
        if let Err(e) = cleanup {
            errors.push(format!("{e:#}"));
        }
        let ok = errors.is_empty();
        event(
            file,
            start,
            trial,
            phase,
            "trial_finished",
            json!({
                "status":if ok {"ok"} else {"failed"},"errors":errors,"ack_ms":ack,
                "qt_frame_callback_ms":completed.as_ref().map(|t|t.open_to_first_frame_ms),
                "content":completed.as_ref().map(|t|&t.content),"timeout_ms":options.timeout.as_millis(),
                "command_path":"quickshell ipc --pid; shelllist.open",
            }),
        )?;
        if !ok {
            bail!(
                "trial {trial} failed; evidence preserved: {}",
                errors.join("; ")
            );
        }
        control.phase("settle");
        sleep(options.settle)?;
    }
    Ok(())
}

pub fn clock_consistent(before: u64, after: u64, monotonic_ms: f64) -> bool {
    // Wall-clock millisecond precision, scheduler-independent because both samples
    // bracket the same work. Reject jumps >20 ms; smaller slews remain a limitation.
    after
        .checked_sub(before)
        .is_some_and(|delta| (delta as f64 - monotonic_ms).abs() <= 20.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn clock_jumps_are_not_latency() {
        assert!(clock_consistent(1000, 1010, 10.8));
        assert!(!clock_consistent(1000, 900, 10.0));
        assert!(!clock_consistent(1000, 2000, 10.0));
    }
}
