use crate::{
    ipc::{Content, Endpoint, Trace},
    sampler::Control,
    scenarios::{self, WarmOptions},
};
use anyhow::Result;
use serde_json::{Value, json};
use std::{
    cell::{Cell, RefCell},
    time::{Duration, Instant},
};

struct Fake {
    visible: Cell<bool>,
    trace: RefCell<Trace>,
    opens: Cell<u32>,
    hides: Cell<u32>,
    stall: bool,
    switch: bool,
    reject: bool,
}
impl Fake {
    fn new() -> Self {
        Self {
            visible: Cell::new(false),
            trace: RefCell::new(Trace {
                schema_version: 1,
                surface: String::new(),
                open_requested_at_ms: 0.0,
                first_frame_at_ms: 0.0,
                open_to_first_frame_ms: -1.0,
                content: Content {
                    surface: String::new(),
                    latency_ms: -1.0,
                    warm: false,
                    recorded_at_ms: 0.0,
                },
            }),
            opens: Cell::new(0),
            hides: Cell::new(0),
            stall: false,
            switch: false,
            reject: false,
        }
    }
}
impl Endpoint for Fake {
    fn call(
        &self,
        method: &str,
        _args: &[&str],
        _timeout: Duration,
        _cleanup: bool,
    ) -> Result<String> {
        Ok(match method {
            "status"=>json!({"visible":self.visible.get(),"surface":if self.switch && self.visible.get(){"wifi"}else{"applications"},"opened":{"applications":self.opens.get()>0}}).to_string(),
            "listSurfaces"=>json!([{"id":"applications"}]).to_string(),
            "responsiveness"=>serde_json::to_string(&*self.trace.borrow())?,
            "open"=>{
                self.opens.set(self.opens.get()+1);
                if self.reject { return Ok("unavailable".into()); }
                self.visible.set(true);
                let now=scenarios::unix_ms() as f64;
                *self.trace.borrow_mut()=Trace {schema_version:1,surface:"applications".into(),open_requested_at_ms:now,
                    first_frame_at_ms:if self.stall{0.0}else{now},open_to_first_frame_ms:if self.stall{-1.0}else{0.0},
                    content:Content{surface:"applications".into(),latency_ms:0.0,warm:true,recorded_at_ms:now}};
                "ok".into()
            },
            "hide"=>{self.hides.set(self.hides.get()+1);self.visible.set(false);String::new()},
            _=>panic!("unexpected method {method}"),
        })
    }
}
fn run(fake: &Fake) -> (Result<()>, Vec<Value>) {
    let options = WarmOptions {
        surface: "applications",
        trials: 2,
        timeout: Duration::from_millis(30),
        poll: Duration::from_millis(1),
        settle: Duration::from_millis(4),
    };
    let mut events = Vec::new();
    let result = scenarios::warm_open(
        fake,
        &mut events,
        Instant::now(),
        &Control::new("test"),
        &options,
    );
    let rows = String::from_utf8(events)
        .unwrap()
        .lines()
        .map(|l| serde_json::from_str(l).unwrap())
        .collect();
    (result, rows)
}
#[test]
fn warmup_is_separate_and_every_trial_is_preserved() {
    let fake = Fake::new();
    let (result, events) = run(&fake);
    result.unwrap();
    assert_eq!(fake.opens.get(), 3);
    assert_eq!(fake.hides.get(), 3);
    let finished: Vec<_> = events
        .iter()
        .filter(|e| e["kind"] == "trial_finished")
        .collect();
    assert_eq!(finished.len(), 3);
    assert_eq!(finished[0]["phase"], "warmup");
    assert!(finished.iter().all(|e| e["data"]["status"] == "ok"));
}
#[test]
fn visible_draft_is_never_closed() {
    let fake = Fake::new();
    fake.visible.set(true);
    let (result, events) = run(&fake);
    assert!(result.is_err());
    assert!(events.is_empty());
    assert_eq!(fake.opens.get(), 0);
    assert_eq!(fake.hides.get(), 0);
}
#[test]
fn timeout_retains_failure_and_cleans_only_owned_surface() {
    let fake = Fake {
        stall: true,
        ..Fake::new()
    };
    let (result, events) = run(&fake);
    assert!(result.is_err());
    assert_eq!(fake.hides.get(), 1);
    let finished = events
        .iter()
        .find(|e| e["kind"] == "trial_finished")
        .unwrap();
    assert_eq!(finished["data"]["status"], "failed");
    assert!(finished["data"]["qt_frame_callback_ms"].is_null());
}
#[test]
fn user_switch_prevents_cleanup_and_success() {
    let fake = Fake {
        switch: true,
        ..Fake::new()
    };
    let (result, events) = run(&fake);
    assert!(result.is_err());
    assert_eq!(fake.hides.get(), 0);
    assert!(fake.visible.get());
    assert_eq!(
        events
            .iter()
            .find(|e| e["kind"] == "trial_finished")
            .unwrap()["data"]["status"],
        "failed"
    );
}
#[test]
fn rejected_open_cannot_pass_or_force_hide() {
    let fake = Fake {
        reject: true,
        ..Fake::new()
    };
    let (result, events) = run(&fake);
    assert!(result.is_err());
    assert_eq!(fake.hides.get(), 0);
    assert_eq!(
        events
            .iter()
            .filter(|e| e["kind"] == "trial_finished")
            .count(),
        1
    );
}
