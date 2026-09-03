use std::{env, fs, io, path::Path};

const SVG_PREFIX: &str = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 720 360\" fill-rule=\"evenodd\">\n";

fn attribute<'a>(line: &'a str, name: &str) -> Option<&'a str> {
    let marker = format!(" {name}=\"");
    let value = line.split_once(&marker)?.1;
    Some(value.split_once('"')?.0)
}

fn generate(input: &Path, output: &Path) -> io::Result<usize> {
    let source = fs::read_to_string(input)?;
    fs::create_dir_all(output)?;
    for entry in fs::read_dir(output)? {
        let path = entry?.path();
        if path.extension().is_some_and(|extension| extension == "svg") {
            fs::remove_file(path)?;
        }
    }

    let mut count = 0;
    for line in source.lines() {
        let Some(id) = attribute(line, "id").and_then(|id| id.strip_prefix("land-")) else {
            continue;
        };
        let Some(path) = attribute(line, "d") else {
            continue;
        };
        let timezone = id.replacen('-', "/", 1);
        let overlay = format!(
            "{SVG_PREFIX}<title>{timezone}</title>\n<path d=\"{path}\" fill=\"#2f8cff\" fill-opacity=\".58\" stroke=\"#e5f2ff\" stroke-width=\"1.8\" vector-effect=\"non-scaling-stroke\"/>\n</svg>\n"
        );
        fs::write(output.join(format!("{id}.svg")), overlay)?;
        count += 1;
    }
    Ok(count)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut arguments = env::args_os().skip(1);
    let input = arguments.next().ok_or("missing input SVG path")?;
    let output = arguments.next().ok_or("missing output directory")?;
    if arguments.next().is_some() {
        return Err("usage: shelllist-timezone-assets <world-map.svg> <output-directory>".into());
    }
    let count = generate(Path::new(&input), Path::new(&output))?;
    if count != 62 {
        return Err(format!("expected 62 visible timezone regions, generated {count}").into());
    }
    println!("generated {count} timezone region assets");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::attribute;

    #[test]
    fn extracts_svg_attributes() {
        let line = r#"<path id="land-Europe-Paris" d="M1,2Z"/>"#;
        assert_eq!(attribute(line, "id"), Some("land-Europe-Paris"));
        assert_eq!(attribute(line, "d"), Some("M1,2Z"));
    }
}
