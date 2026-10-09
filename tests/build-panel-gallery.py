#!/usr/bin/env python3
"""Build a local, non-golden before/after gallery from the explicit Qt fixtures."""
import argparse
import html
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANELS = [("applications", "Applications", "resources-minimum", "resources"),
          ("wifi", "Wi-Fi", "", ""), ("bluetooth", "Bluetooth", "adapter-general", "adapter-general"),
          ("clipboard", "Clipboard", "info", "info"), ("displays", "Displays", "settings", "settings"),
          ("battery", "Battery & Power", "care", "care"), ("activity", "Activity", "schedule", "schedule"),
          ("notifications", "Notifications", "controls", "controls"),
          ("time-weather", "Time & Weather", "time", "time"), ("audio", "Audio", "", ""),
          ("media", "Media", "", ""), ("tray", "Tray", "", "")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, default=ROOT / "target/panel-standardization")
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    output = evidence / "phase4/gallery.html"
    output.parent.mkdir(parents=True, exist_ok=True)

    def image(path, caption):
        if not path.is_file():
            return f"<p>Not captured: {html.escape(caption)}</p>"
        url = html.escape(os.path.relpath(path, output.parent), quote=True)
        return f'<figure><a href="{url}"><img loading="lazy" src="{url}" alt="{html.escape(caption, quote=True)}"></a><figcaption>{html.escape(caption)}</figcaption></figure>'

    def name(panel, scheme, suffix):
        return f"{panel}-{scheme}" + (f"-{suffix}" if suffix else "") + ".png"

    body = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Shelllist panel acceptance gallery</title>',
            '<style>body{font:16px system-ui;margin:auto;padding:24px;max-width:1440px;background:#17151c;color:#e9e3ee}a{color:#cfc0ff}h1,h2{line-height:1.2}section,details{margin:24px 0}summary{cursor:pointer;padding:12px;background:#302b39}.pair,.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}figure{margin:0}img{width:100%;height:auto;background:#25212b}figcaption{padding:8px;font-size:14px}p{max-width:90ch;line-height:1.5}@media(max-width:750px){.pair,.grid{grid-template-columns:1fr}}</style>',
            '<h1>Shelllist · twelve-panel acceptance gallery</h1><p>Actual Qt fixture captures, not the illustrative proposal and not pixel goldens. Click any image for full resolution. Synthetic snapshots and recording transports only; these images do not demonstrate live hardware changes. Before/after fixture data differ where native models or readiness required repair, notably measured Resources and Displays.</p>',
            '<p>Role specification, panel matrix, exception owners and evidence limits: <a href="../../../docs/panel-ui-standardization.md">panel-ui-standardization.md</a>. Source, offscreen, fractional and live Wayland evidence are recorded separately. Hardware IME and a human screen-reader session are not claimed.</p>']
    for panel, title, after_suffix, before_suffix in PANELS:
        body.append(f'<section id="{panel}"><h2>{html.escape(title)}</h2>')
        for scheme in ["dark", "light"]:
            if scheme == "light":
                body.append("<details><summary>Light comparison</summary>")
            body.append('<div class="pair">')
            body.append(image(evidence / "phase0/captures" / name(panel, scheme, before_suffix), f"Before · {title} · {scheme}"))
            body.append(image(evidence / "phase4/captures" / name(panel, scheme, after_suffix), f"After · {title} · {scheme}"))
            body.append("</div>")
            if scheme == "light":
                body.append("</details>")
        body.append("</section>")
    for folder, title in [("captures", "All panels, subpages, minimum sizes, errors and pending states"),
                          ("forms", "Dense forms, native state feedback and narrow diagnostics"),
                          ("displays", "Display drafts, drag, trial and Focus subpages"),
                          ("fractional", "Offscreen fractional-scale captures (1.25×)"),
                          ("wayland", "Live Wayland/RHI fixture captures")]:
        images = sorted((evidence / "phase4" / folder).glob("*.png"))
        if images:
            body.append(f"<details><summary>{html.escape(title)} · {len(images)} images</summary><div class=grid>")
            body.extend(image(path, path.stem) for path in images)
            body.append("</div></details>")
    body.append("</html>")
    output.write_text("\n".join(body))
    print(output)


if __name__ == "__main__":
    main()
