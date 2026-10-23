//! Bounded native Qt observations. Never infer line/branch coverage or frame timing.
use crate::{command, procfs::hash_file};
use anyhow::{Context, Result, bail, ensure};
use clap::Args;
use quick_xml::{Reader, events::Event};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::{self, File},
    io::{BufReader, BufWriter, Write},
    net::TcpListener,
    path::{Path, PathBuf},
    process::Command,
    sync::atomic::Ordering,
    time::{Duration, Instant},
};

const MAX_TRACE_BYTES: u64 = 512 * 1024 * 1024;
const MAX_EVENTS: usize = 5_000_000;
const REPORTS: [&str; 2] = ["coverage.json", "runtime.json"];

#[derive(Args)]
pub struct Options {
    #[arg(long, default_value = ".")]
    pub root: PathBuf,
    #[arg(last = true)]
    pub arguments: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
struct Source {
    file: String,
    sha256: String,
}
type Sources = BTreeMap<PathBuf, Source>;

fn sources(root: &Path) -> Result<Sources> {
    #[derive(Deserialize)]
    struct Config {
        source_roots: Vec<String>,
    }
    let config: Config =
        serde_json::from_reader(File::open(root.join("qmlqualitylens.config.json"))?)?;
    let mut sources = BTreeMap::new();
    let mut visited = BTreeSet::new();
    for directory in config.source_roots {
        walk(root, &root.join(directory), &mut visited, &mut sources)?;
    }
    Ok(sources)
}

fn walk(
    root: &Path,
    path: &Path,
    visited: &mut BTreeSet<PathBuf>,
    sources: &mut Sources,
) -> Result<()> {
    let real = path.canonicalize()?;
    if !real.starts_with(root) || !visited.insert(real.clone()) {
        return Ok(());
    }
    if real.is_dir() {
        let mut entries = fs::read_dir(path)?.collect::<std::io::Result<Vec<_>>>()?;
        entries.sort_by_key(|entry| entry.file_name());
        for entry in entries {
            if ["target", "node_modules", ".git", ".direnv", "__pycache__"]
                .iter()
                .any(|name| entry.file_name() == *name)
            {
                continue;
            }
            walk(root, &entry.path(), visited, sources)?;
        }
    } else if matches!(
        real.extension().and_then(|s| s.to_str()),
        Some("qml" | "js")
    ) {
        sources.insert(
            real,
            Source {
                file: path.strip_prefix(root)?.to_string_lossy().into(),
                sha256: hash_file(path)?,
            },
        );
    }
    Ok(())
}

#[derive(Default, Serialize)]
struct Observed {
    file: String,
    sha256: String,
    objects: BTreeSet<u64>,
    bindings: BTreeSet<u64>,
    executables: BTreeSet<u64>,
}
#[derive(Clone)]
struct Definition {
    source: Source,
    kind: String,
    line: u64,
}
fn definition(metadata: &BTreeMap<String, String>, sources: &Sources) -> Option<Definition> {
    let kind = metadata.get("type")?;
    if !matches!(
        kind.as_str(),
        "Creating" | "Binding" | "Javascript" | "HandlingSignal"
    ) || metadata.get("details").is_some_and(|s| s == "%entry")
    {
        return None;
    }
    let path = url::Url::parse(metadata.get("filename")?)
        .ok()?
        .to_file_path()
        .ok()?
        .canonicalize()
        .ok()?;
    let line: u64 = metadata.get("line")?.parse().ok()?;
    if line == 0 {
        return None;
    }
    Some(Definition {
        source: sources.get(&path)?.clone(),
        kind: kind.clone(),
        line,
    })
}

fn attributes(event: &quick_xml::events::BytesStart<'_>) -> Result<BTreeMap<String, String>> {
    event
        .attributes()
        .map(|a| {
            let a = a?;
            Ok((
                std::str::from_utf8(a.key.as_ref())?.to_owned(),
                a.unescape_value()?.into_owned(),
            ))
        })
        .collect()
}

/// Stream ranges directly to the staging runtime file; memory is bounded by
/// definitions and unique observed source lines, not the number of ranges.
fn normalize(
    trace: &Path,
    sources: &Sources,
    environment: &Value,
    runtime: &mut impl Write,
) -> Result<(Value, usize)> {
    ensure!(
        fs::metadata(trace)?.len() <= MAX_TRACE_BYTES,
        "Qt trace exceeds size limit"
    );
    let deadline = Instant::now() + Duration::from_secs(60);
    let mut reader = Reader::from_reader(BufReader::new(File::open(trace)?));
    let mut buffer = Vec::new();
    let mut definitions = BTreeMap::<String, Option<Definition>>::new();
    let mut observed = BTreeMap::<String, Observed>::new();
    let mut metadata = BTreeMap::new();
    let mut definition_id = None;
    let mut stack = Vec::<String>::new();
    let (mut ignored, mut count, mut ranges, mut definition_count) = (0, 0, 0, 0);
    runtime.write_all(b"{\"events\":[")?;
    loop {
        ensure!(
            Instant::now() < deadline,
            "Qt trace normalization timed out"
        );
        ensure!(!command::INTERRUPTED.load(Ordering::Relaxed), "interrupted");
        let event = reader.read_event_into(&mut buffer)?;
        ensure!(
            reader.buffer_position() <= MAX_TRACE_BYTES,
            "Qt trace grew beyond size limit"
        );
        match event {
            Event::Start(ref element) | Event::Empty(ref element) => {
                let name = std::str::from_utf8(element.name().as_ref())?.to_owned();
                let attrs = attributes(element)?;
                if name == "event" {
                    ensure!(definition_id.is_none(), "nested event definition");
                    definition_count += 1;
                    ensure!(
                        definition_count <= MAX_EVENTS,
                        "Qt definition limit exceeded"
                    );
                    definition_id =
                        Some(attrs.get("index").context("event missing index")?.clone());
                    metadata.clear();
                } else if name == "range" {
                    ranges += 1;
                    ensure!(ranges <= MAX_EVENTS, "Qt range limit exceeded");
                    if let Some(Some(def)) =
                        attrs.get("eventIndex").and_then(|id| definitions.get(id))
                    {
                        let record =
                            observed
                                .entry(def.source.file.clone())
                                .or_insert_with(|| Observed {
                                    file: def.source.file.clone(),
                                    sha256: def.source.sha256.clone(),
                                    ..Default::default()
                                });
                        match def.kind.as_str() {
                            "Creating" => &mut record.objects,
                            "Binding" => &mut record.bindings,
                            _ => &mut record.executables,
                        }
                        .insert(def.line);
                        if let Some(duration) = attrs.get("duration") {
                            let duration: u64 =
                                duration.parse().context("invalid/negative Qt duration")?;
                            if count > 0 {
                                runtime.write_all(b",")?;
                            }
                            serde_json::to_writer(
                                &mut *runtime,
                                &json!({"category":def.kind, "duration_ms":duration as f64 / 1_000_000.0,"file":def.source.file,"line":def.line}),
                            )?;
                            count += 1;
                        }
                    } else {
                        ignored += 1;
                    }
                }
                if matches!(event, Event::Start(_)) {
                    stack.push(name);
                    ensure!(stack.len() <= 128, "Qt XML nesting limit exceeded");
                } else if name == "event" {
                    definitions.insert(definition_id.take().unwrap(), None);
                }
            }
            Event::Text(text) if definition_id.is_some() => {
                if let Some(tag) = stack.last() {
                    metadata
                        .entry(tag.clone())
                        .or_insert_with(String::new)
                        .push_str(&quick_xml::escape::unescape(&text.decode()?)?);
                }
            }
            Event::CData(text) if definition_id.is_some() => {
                if let Some(tag) = stack.last() {
                    metadata
                        .entry(tag.clone())
                        .or_insert_with(String::new)
                        .push_str(&text.decode()?);
                }
            }
            Event::End(element) => {
                if element.name().as_ref() == b"event" {
                    let id = definition_id.take().context("event without start")?;
                    definitions.insert(id, definition(&metadata, sources));
                }
                stack.pop().context("unbalanced Qt XML")?;
            }
            Event::DocType(_) => bail!("Qt trace must not contain a DTD"),
            Event::Eof => break,
            _ => {}
        }
        buffer.clear();
    }
    ensure!(stack.is_empty(), "truncated Qt XML");
    ensure!(
        !observed.is_empty() && count > 0,
        "Qt trace has no mapped project execution observations"
    );
    let performance = json!({"scenario":"qml-tests", "environment":environment, "ignored_framework_or_nonexecution_events":ignored,"observed_event_count":count});
    runtime.write_all(b"],")?;
    let suffix = serde_json::to_string(&performance)?;
    runtime.write_all(&suffix.as_bytes()[1..])?;
    runtime.write_all(b"\n")?;
    Ok((
        json!({"format":"qml-profiler-observations","environment":environment,"files":observed.into_values().collect::<Vec<_>>()}),
        count,
    ))
}

fn publish(
    root: &Path,
    trace: &Path,
    before: &Sources,
    environment: &Value,
    output: &Path,
) -> Result<usize> {
    let stage = tempfile::Builder::new()
        .prefix(".profile-")
        .tempdir_in(output)?;
    let mut runtime = BufWriter::new(File::create(stage.path().join("runtime.json"))?);
    let (coverage, count) = normalize(trace, before, environment, &mut runtime)?;
    runtime.flush()?;
    serde_json::to_writer(File::create(stage.path().join("coverage.json"))?, &coverage)?;
    ensure!(
        *before == sources(root)?,
        "Sources changed during profiling; refusing stale observations"
    );
    for report in REPORTS {
        fs::rename(stage.path().join(report), output.join(report))?;
    }
    Ok(count)
}

pub fn run(options: Options) -> Result<()> {
    let root = options.root.canonicalize()?;
    let output = root.join("target/profiling");
    fs::create_dir_all(&output)?;
    // Old success evidence must never survive a failed new collection.
    for name in REPORTS {
        let path = output.join(name);
        if path.exists() {
            fs::remove_file(path)?;
        }
    }
    let result = (|| {
        let before = sources(&root)?;
        let trace = {
            let trace = output.join("tests.qtd");
            if trace.exists() {
                fs::remove_file(&trace)?;
            }
            let port = TcpListener::bind(("127.0.0.1", 0))?.local_addr()?.port();
            let mut child = Command::new("qmlprofiler");
            child
                .current_dir(&root)
                .env("QT_QPA_PLATFORM", "offscreen")
                .env("QT_QUICK_BACKEND", "software")
                .env("QML_XHR_ALLOW_FILE_READ", "1")
                .env("TZ", "UTC")
                .args([
                    "--port",
                    &port.to_string(),
                    "--include",
                    "binding,creating,handlingsignal",
                    "--output",
                ])
                .arg(&trace)
                .arg(root.join("tests/run-qmlquality-tests.sh"))
                .args(&options.arguments);
            let log = command::run_configured(child, Duration::from_secs(180), false, true)?;
            print!("{log}");
            trace
        };
        let version = command::run(
            Path::new("qmllint"),
            &["--version"],
            Duration::from_secs(5),
            false,
        )?;
        let qt = version
            .split_whitespace()
            .find(|word| {
                word.split('.').count() == 3 && word.chars().all(|c| c.is_ascii_digit() || c == '.')
            })
            .context("Cannot determine Qt version")?;
        let provenance = json!({"qt":qt,"platform":"offscreen","renderer":"software","source_format":"qt-qtd-nanoseconds","frames_measured":false,
            "scope":"QML test-suite bindings, creation and signal handlers; includes setup/teardown and profiler overhead",
            "omitted":"Standalone JavaScript functions (unreliable multi-engine attribution); display frame timing",
            "trace_sha256":hash_file(&trace)?,"source_sha256":before.values().map(|s| (s.file.clone(),s.sha256.clone())).collect::<BTreeMap<_,_>>()});
        let count = publish(&root, &trace, &before, &provenance, &output)?;
        eprintln!("Qt profiler: {count} project duration events");
        Ok(())
    })();
    if result.is_err() {
        for name in REPORTS {
            let _ = fs::remove_file(output.join(name));
        }
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> (tempfile::TempDir, PathBuf, Sources) {
        let dir = tempfile::tempdir().unwrap();
        fs::write(
            dir.path().join("qmlqualitylens.config.json"),
            r#"{"source_roots":["."]}"#,
        )
        .unwrap();
        fs::write(dir.path().join("Source file.qml"), "Item {}\n").unwrap();
        let trace = dir.path().join("trace.qtd");
        let url = url::Url::from_file_path(dir.path().join("Source file.qml")).unwrap();
        fs::write(&trace, format!("<trace><eventData><event index=\"1\"><type>Binding</type><filename>{url}</filename><line>1</line></event></eventData><profilerDataModel><range eventIndex=\"1\" duration=\"2000000\"/><range eventIndex=\"1\" duration=\"1000000\"/><range eventIndex=\"9\"/></profilerDataModel></trace>")).unwrap();
        let sources = sources(dir.path()).unwrap();
        (dir, trace, sources)
    }
    #[test]
    fn streamed_ranges_and_source_fence() {
        let (dir, trace, sources) = fixture();
        assert_eq!(
            publish(dir.path(), &trace, &sources, &json!({}), dir.path()).unwrap(),
            2
        );
        let runtime: Value =
            serde_json::from_reader(File::open(dir.path().join("runtime.json")).unwrap()).unwrap();
        assert_eq!(runtime["events"][0]["duration_ms"], 2.0);
        assert_eq!(runtime["ignored_framework_or_nonexecution_events"], 1);
        let coverage: Value =
            serde_json::from_reader(File::open(dir.path().join("coverage.json")).unwrap()).unwrap();
        assert_eq!(coverage["files"][0]["bindings"], json!([1]));
        fs::write(dir.path().join("Source file.qml"), "changed").unwrap();
        assert!(
            publish(dir.path(), &trace, &sources, &json!({}), dir.path())
                .unwrap_err()
                .to_string()
                .contains("Sources changed")
        );
        assert!(!fs::read_dir(dir.path()).unwrap().any(|e| {
            e.unwrap()
                .file_name()
                .to_string_lossy()
                .starts_with(".profile-")
        }));
    }
    #[test]
    fn invalid_empty_negative_and_oversized_traces_fail_closed() {
        let (dir, trace, sources) = fixture();
        let original = fs::read_to_string(&trace).unwrap();
        for text in [
            "<trace/>",
            "<trace>",
            "<!DOCTYPE trace><trace/>",
            &original.replace("2000000", "-1"),
        ] {
            fs::write(&trace, text).unwrap();
            assert!(normalize(&trace, &sources, &json!({}), &mut Vec::new()).is_err());
        }
        File::create(&trace)
            .unwrap()
            .set_len(MAX_TRACE_BYTES + 1)
            .unwrap();
        assert!(normalize(&trace, &sources, &json!({}), &mut Vec::new()).is_err());
        drop(dir);
    }
    #[test]
    fn failed_collection_removes_previous_reports() {
        let (dir, _, _) = fixture();
        let output = dir.path().join("target/profiling");
        fs::create_dir_all(&output).unwrap();
        for name in REPORTS {
            fs::write(output.join(name), "old evidence").unwrap();
        }
        fs::write(
            dir.path().join("qmlqualitylens.config.json"),
            "invalid config",
        )
        .unwrap();
        assert!(
            run(Options {
                root: dir.path().into(),
                arguments: vec![]
            })
            .is_err()
        );
        for name in REPORTS {
            assert!(!output.join(name).exists());
        }
    }
}
