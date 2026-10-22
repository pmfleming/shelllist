//! Role-based resource comparisons. Never pair ambiguous members by ephemeral PID.
use crate::{artifacts::scope_role, model::*};
use serde_json::{Value, json};
use std::collections::{BTreeMap, BTreeSet};

pub struct Scopes {
    pub deltas: Vec<Value>,
    pub provenance: Vec<Value>,
    pub unpaired: Vec<Value>,
}

pub fn targets(manifest: &Manifest) -> BTreeMap<&str, Vec<&Target>> {
    let mut roles = BTreeMap::<_, Vec<_>>::new();
    for t in &manifest.targets {
        roles.entry(scope_role(&t.label)).or_default().push(t);
    }
    roles
}

pub fn scopes(a: &Manifest, b: &Manifest, sa: &Summary, sb: &Summary) -> Scopes {
    let left = targets(a);
    let right = targets(b);
    let roles: BTreeSet<_> = left.keys().chain(right.keys()).copied().collect();
    let mut result = Scopes {
        deltas: vec![],
        provenance: vec![],
        unpaired: vec![],
    };
    for role in roles {
        let aa = left.get(role).map(Vec::as_slice).unwrap_or_default();
        let bb = right.get(role).map(Vec::as_slice).unwrap_or_default();
        let hashes = |ts: &[&Target]| {
            let mut hashes: Vec<_> = ts
                .iter()
                .map(|t| t.identity.executable_sha256.clone())
                .collect();
            hashes.sort();
            hashes
        };
        result
            .provenance
            .push(json!({"scope":role,"baseline":aa,"candidate":bb,
            "executable_hashes_changed":hashes(aa) != hashes(bb)}));
        if aa.len() != 1 || bb.len() != 1 {
            result.unpaired.push(json!({"scope":role,"baseline_members":aa.len(),"candidate_members":bb.len(),
                "reason":"absent or ambiguous members; use unique stable --related-pid labels; no PID pairing or additive memory total"}));
            continue;
        }
        let ar: BTreeMap<_, _> = sa
            .resources
            .iter()
            .filter(|r| r.label == aa[0].label)
            .map(|r| (r.phase.as_str(), r))
            .collect();
        let br: BTreeMap<_, _> = sb
            .resources
            .iter()
            .filter(|r| r.label == bb[0].label)
            .map(|r| (r.phase.as_str(), r))
            .collect();
        for phase in ar.keys().chain(br.keys()).copied().collect::<BTreeSet<_>>() {
            let a = ar.get(phase).copied();
            let b = br.get(phase).copied();
            for (name, av, bv, ac, bc) in resource_values(a, b) {
                let mut row = delta(&format!("{role} / {phase} / {name}"), av, bv);
                row["scope"] = json!(role);
                row["phase"] = json!(phase);
                row["baseline_covered_s"] = json!(ac);
                row["candidate_covered_s"] = json!(bc);
                row["unavailable_reason"] = if av.is_none() || bv.is_none() {
                    json!(
                        "one or both scopes lack a valid observation; inspect raw gaps and coverage"
                    )
                } else {
                    Value::Null
                };
                result.deltas.push(row);
            }
        }
    }
    // Cgroup scope paths are part of comparison_context. Their member PIDs are
    // intentionally not paired: the kernel accounts the entire service lifetime.
    for group in &a.cgroups {
        let candidate = b
            .cgroups
            .iter()
            .find(|g| g.label == group.label && g.path == group.path);
        result.provenance.push(json!({"scope":group.label,"baseline":group,"candidate":candidate,"accounting":"hierarchical cgroup v2; overlaps process scopes"}));
        if candidate.is_none() {
            result
                .unpaired
                .push(json!({"scope":group.label,"reason":"cgroup absent or path changed"}));
            continue;
        }
        let phases: BTreeSet<_> = sa
            .resources
            .iter()
            .chain(&sb.resources)
            .filter(|r| r.label == group.label)
            .map(|r| &r.phase)
            .collect();
        for phase in phases {
            let left = sa
                .resources
                .iter()
                .find(|r| r.label == group.label && &r.phase == phase);
            let right = sb
                .resources
                .iter()
                .find(|r| r.label == group.label && &r.phase == phase);
            for (name, av, bv, ac, bc) in resource_values(left, right) {
                let mut row = delta(&format!("{} / {phase} / {name}", group.label), av, bv);
                row["scope"] = json!(group.label);
                row["phase"] = json!(phase);
                row["baseline_covered_s"] = json!(ac);
                row["candidate_covered_s"] = json!(bc);
                result.deltas.push(row);
            }
        }
    }
    result
}

type ResourceValue = (
    &'static str,
    Option<f64>,
    Option<f64>,
    Option<f64>,
    Option<f64>,
);
fn resource_values(a: Option<&ResourceSummary>, b: Option<&ResourceSummary>) -> [ResourceValue; 6] {
    [
        (
            "cpu_percent",
            a.and_then(|r| r.cpu_percent_one_core),
            b.and_then(|r| r.cpu_percent_one_core),
            a.map(|r| r.valid_cpu_seconds),
            b.map(|r| r.valid_cpu_seconds),
        ),
        (
            "rss_peak_bytes",
            a.and_then(|r| r.rss_sampled_peak_bytes).map(|n| n as f64),
            b.and_then(|r| r.rss_sampled_peak_bytes).map(|n| n as f64),
            None,
            None,
        ),
        (
            "pss_peak_bytes",
            a.and_then(|r| r.pss_sampled_peak_bytes).map(|n| n as f64),
            b.and_then(|r| r.pss_sampled_peak_bytes).map(|n| n as f64),
            None,
            None,
        ),
        (
            "cgroup_memory_peak_bytes",
            a.and_then(|r| r.cgroup_memory_peak_bytes).map(|n| n as f64),
            b.and_then(|r| r.cgroup_memory_peak_bytes).map(|n| n as f64),
            None,
            None,
        ),
        (
            "read_observed_bytes",
            a.and_then(|r| r.io_read_observed_bytes),
            b.and_then(|r| r.io_read_observed_bytes),
            a.map(|r| r.io_read_covered_s),
            b.map(|r| r.io_read_covered_s),
        ),
        (
            "write_observed_bytes",
            a.and_then(|r| r.io_write_observed_bytes),
            b.and_then(|r| r.io_write_observed_bytes),
            a.map(|r| r.io_write_covered_s),
            b.map(|r| r.io_write_covered_s),
        ),
    ]
}

pub fn delta(name: &str, a: Option<f64>, b: Option<f64>) -> Value {
    json!({"metric":name,"baseline":a,"candidate":b,"absolute_delta":a.zip(b).map(|(a,b)|b-a),"relative_percent":a.zip(b).filter(|(a,_)|a.abs()>1e-9).map(|(a,b)|(b-a)/a*100.0)})
}
