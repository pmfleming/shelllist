use crate::model::{Counter, Identity};
use anyhow::{Context, Result, bail, ensure};
use sha2::{Digest, Sha256};
use std::{collections::BTreeMap, fs, io::Read, os::unix::fs::MetadataExt, path::Path};

#[derive(Debug)]
pub struct Stat {
    pub start_ticks: u64,
    pub cpu_ticks: u64,
    pub minor_faults: u64,
    pub major_faults: u64,
}

pub fn parse_stat(text: &str) -> Result<Stat> {
    // comm may contain spaces and ')' characters. Fields after its LAST ')' are numeric.
    let (_, rest) = text
        .rsplit_once(')')
        .context("missing stat comm terminator")?;
    let fields: Vec<_> = rest.split_whitespace().collect();
    let number = |field: usize| -> Result<u64> {
        fields
            .get(field - 3)
            .context("short stat")?
            .parse()
            .context("invalid stat counter")
    };
    Ok(Stat {
        start_ticks: number(22)?,
        cpu_ticks: number(14)?
            .checked_add(number(15)?)
            .context("CPU counter overflow")?,
        minor_faults: number(10)?,
        major_faults: number(12)?,
    })
}

pub fn hash_file(path: &Path) -> Result<String> {
    let mut file = fs::File::open(path).with_context(|| format!("read {}", path.display()))?;
    let mut hash = Sha256::new();
    let mut buffer = [0; 65536];
    loop {
        let n = file.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        hash.update(&buffer[..n]);
    }
    Ok(format!("{:x}", hash.finalize()))
}

pub fn identity(pid: u32) -> Result<Identity> {
    ensure!(pid > 0, "PID must be positive");
    let base = format!("/proc/{pid}");
    let stat = parse_stat(&fs::read_to_string(format!("{base}/stat"))?)?;
    let uid = fs::metadata(&base)?.uid();
    // SAFETY: geteuid has no preconditions.
    ensure!(
        uid == unsafe { libc::geteuid() },
        "target must belong to the current user"
    );
    let executable = fs::read_link(format!("{base}/exe"))?
        .to_string_lossy()
        .into_owned();
    let executable_sha256 = hash_file(Path::new(&format!("{base}/exe")))?;
    let result = Identity {
        pid,
        start_ticks: stat.start_ticks,
        uid,
        executable,
        executable_sha256,
        boot_id: fs::read_to_string("/proc/sys/kernel/random/boot_id")?
            .trim()
            .into(),
    };
    verify(&result)?;
    Ok(result)
}

pub fn verify(id: &Identity) -> Result<()> {
    verified_stat(id).map(|_| ())
}

fn verified_stat(id: &Identity) -> Result<Stat> {
    let base = format!("/proc/{}", id.pid);
    let stat = parse_stat(&fs::read_to_string(format!("{base}/stat"))?)?;
    ensure!(stat.start_ticks == id.start_ticks, "PID identity changed");
    ensure!(fs::metadata(&base)?.uid() == id.uid, "target UID changed");
    ensure!(
        fs::read_link(format!("{base}/exe"))?.to_string_lossy() == id.executable,
        "target executable changed"
    );
    Ok(stat)
}

pub fn ticks_per_second() -> Result<u64> {
    // SAFETY: sysconf with a defined selector has no pointer arguments.
    let ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) };
    ensure!(ticks > 0, "cannot determine CLK_TCK");
    Ok(ticks as u64)
}

pub fn fields(text: &str) -> BTreeMap<&str, &str> {
    text.lines()
        .filter_map(|line| line.split_once(':'))
        .map(|(k, v)| (k.trim(), v.trim()))
        .collect()
}

pub fn bytes(value: &str) -> Result<u64> {
    let mut parts = value.split_whitespace();
    let n: u64 = parts.next().context("missing value")?.parse()?;
    let multiplier = match parts.next() {
        Some("kB" | "KiB") => 1024,
        Some("MiB") => 1024 * 1024,
        Some("B" | "bytes") => 1,
        None if n == 0 => 1,
        _ => bail!("unknown memory unit"),
    };
    ensure!(parts.next().is_none(), "trailing memory tokens");
    n.checked_mul(multiplier).context("memory overflow")
}

fn insert_fields(
    out: &mut BTreeMap<String, Counter>,
    text: &Result<String>,
    source: &str,
    keys: &[(&str, &str, &str)],
) {
    // Each proc file is parsed once, not once per requested counter.
    let parsed_fields = text
        .as_ref()
        .map(|s| fields(s))
        .map_err(|e| format!("{e:#}"));
    for &(name, key, unit) in keys {
        let parsed = parsed_fields
            .as_ref()
            .map_err(Clone::clone)
            .and_then(|fields| {
                let value = fields.get(key).ok_or_else(|| format!("missing {key}"))?;
                if unit == "bytes" {
                    bytes(value).map_err(|e| e.to_string())
                } else {
                    value.parse::<u64>().map_err(|e| e.to_string())
                }
            });
        let counter = match parsed {
            Ok(n) => Counter::new(n, unit, source),
            Err(e) => Counter::missing(unit, source, e),
        };
        out.insert(name.into(), counter);
    }
}

pub fn counters(id: &Identity, heavy: bool) -> Result<BTreeMap<String, Counter>> {
    // Reuse the stat snapshot that established the pre-read identity. The
    // independent post-read verification below still rejects exits/PID reuse.
    let stat = verified_stat(id)?;
    let root = format!("/proc/{}", id.pid);
    let mut out = BTreeMap::new();
    for (name, n, unit) in [
        ("cpu_ticks", stat.cpu_ticks, "ticks"),
        ("minor_faults", stat.minor_faults, "count"),
        ("major_faults", stat.major_faults, "count"),
    ] {
        out.insert(name.into(), Counter::new(n, unit, "proc/stat"));
    }
    insert_fields(
        &mut out,
        &fs::read_to_string(format!("{root}/status")).map_err(Into::into),
        "proc/status",
        &[
            ("rss_bytes", "VmRSS", "bytes"),
            ("hwm_bytes", "VmHWM", "bytes"),
            ("threads", "Threads", "count"),
        ],
    );
    let io = fs::read_to_string(format!("{root}/io")).map_err(Into::into);
    // io's byte counters are unitless; parse numerically, then annotate bytes.
    insert_fields(
        &mut out,
        &io,
        "proc/io",
        &[
            ("read_bytes", "read_bytes", "count"),
            ("write_bytes", "write_bytes", "count"),
            ("rchar", "rchar", "count"),
            ("wchar", "wchar", "count"),
            ("syscr", "syscr", "count"),
            ("syscw", "syscw", "count"),
        ],
    );
    for key in ["read_bytes", "write_bytes", "rchar", "wchar"] {
        out.get_mut(key).unwrap().unit = "bytes".into();
    }
    let pss = if heavy {
        fs::read_to_string(format!("{root}/smaps_rollup")).map_err(Into::into)
    } else {
        Err(anyhow::anyhow!("not sampled at this cadence"))
    };
    insert_fields(
        &mut out,
        &pss,
        "proc/smaps_rollup",
        &[
            ("pss_bytes", "Pss", "bytes"),
            ("private_clean_bytes", "Private_Clean", "bytes"),
            ("private_dirty_bytes", "Private_Dirty", "bytes"),
        ],
    );
    verify(id)?;
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn stat_names_and_units() {
        let mut f = vec!["0"; 22];
        f[0] = "S";
        f[7] = "5";
        f[9] = "2";
        f[11] = "10";
        f[12] = "20";
        f[19] = "900";
        let s = parse_stat(&format!("7 (a ) tricky name) {}", f.join(" "))).unwrap();
        assert_eq!(
            (s.cpu_ticks, s.start_ticks, s.minor_faults, s.major_faults),
            (30, 900, 5, 2)
        );
        assert!(parse_stat("1 (x) S").is_err());
        assert_eq!(bytes("12 kB").unwrap(), 12288);
        assert_eq!(bytes("0").unwrap(), 0);
        assert!(bytes("12").is_err());
        assert!(bytes("18446744073709551615 KiB").is_err());
    }
    #[test]
    fn shared_field_parse_keeps_missing_invalid_and_denied_counters_distinct() {
        let mut out = BTreeMap::new();
        insert_fields(
            &mut out,
            &Ok("VmRSS: 12 kB\nVmHWM: bad\n".into()),
            "fixture",
            &[
                ("rss", "VmRSS", "bytes"),
                ("peak", "VmHWM", "bytes"),
                ("threads", "Threads", "count"),
            ],
        );
        assert_eq!(out["rss"].value, Some(12288));
        assert!(out["peak"].value.is_none());
        assert_eq!(out["threads"].reason.as_deref(), Some("missing Threads"));
        insert_fields(
            &mut out,
            &Err(anyhow::anyhow!("permission denied")),
            "fixture",
            &[("rss", "VmRSS", "bytes"), ("peak", "VmHWM", "bytes")],
        );
        assert_eq!(out["rss"].reason.as_deref(), Some("permission denied"));
        assert_eq!(out["peak"].reason, out["rss"].reason);
    }

    #[test]
    fn detects_reuse() {
        let mut id = identity(std::process::id()).unwrap();
        id.start_ticks += 1;
        assert!(verify(&id).is_err());
    }
}
