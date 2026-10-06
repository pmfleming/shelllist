#!/usr/bin/env python3
"""Build the offline checklist from tst_header_review.qml's production captures."""
import base64
import html
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/reviews/external-header-review.html"
CAPTURES = ROOT / "target/external-header-review"

ITEMS = [
    dict(id="wifi-device-dhcp", panel="Wi-Fi", route="Selected network → Security & Privacy",
         external="Device & DHCP details", internal=["Technical details"],
         source="wifi/AdvancedSecurityPane.qml", line=121, anchor="wifiSecurityDiagnostics",
         kind="Single-card heading", note="The same pattern as your screenshot. The outer heading introduces one already-titled card.",
         preserve="Keep the Technical details title, all diagnostic values, and the information-only section semantics."),
    dict(id="wifi-connection-network", panel="Wi-Fi", route="Selected network → Network Details",
         external="Connection & network details", internal=["Connection", "Network details"],
         source="wifi/NetworkDetailCards.qml", line=25, anchor="wifiNetworkDiagnostics",
         kind="Multi-card grouping", note="One outer heading groups two cards, each with its own title. Unlike the first example, it supplies a group name rather than naming a single card twice.",
         preserve="Keep both cards and their titles; only the outer group heading is under review."),
    dict(id="battery-hardware", panel="Battery", route="Battery & Power → Battery",
         external="Hardware details", internal=["Hardware"],
         source="battery/BatteryCarePane.qml", line=93, anchor="batteryHardwareDetails",
         kind="Single-card heading", note="The outer and inner headings both describe the same hardware information.",
         preserve="Keep Hardware and all energy, capacity, device and serial fields; retain information-only semantics."),
    dict(id="battery-automation", panel="Battery", route="Battery & Power → Suspend",
         external="Battery levels & hardware tuning", internal=["Battery levels & actions", "Hardware power tuning"],
         source="battery/PowerControlsPane.qml", line=23, anchor="batteryAutomationSection",
         kind="Multi-card grouping", note="The outer heading groups battery-level automation and optional hardware tuning. The second card is conditional on reported hardware capabilities.",
         preserve="Keep both card titles, capability guards, all controls and their save behaviour."),
    dict(id="applications-composition", panel="Applications", route="Selected application → Resources",
         external="Resource composition", internal=["Application data", "Referenced files", "GPU allocation", "Energy share"],
         source="launcher/ApplicationResourceHistory.qml", line=102, anchor="Resource composition",
         kind="Metric-card grouping", note="An external section label sits above four individually labelled metric cards. This is a grouping heading, not an exact wording duplicate.",
         preserve="Keep all four cards and their individual metric labels."),
    dict(id="applications-activity", panel="Applications", route="Selected application → Resources",
         external="Activity overview / Retained activity", internal=["Shared timeline"],
         source="launcher/ApplicationResourceHistory.qml", line=198, anchor="Activity overview",
         kind="Stateful chart heading", note="The external label is Activity overview for a running application, Activity overview · Loading… while fetching, and Retained activity for a stopped application. The chart also has its own Shared timeline title.",
         preserve="Keep Shared timeline and the 30m / 2h / 24h selector. If deleting, retain loading/retained-measurement status elsewhere rather than silently losing that information."),
]

AUDIT = [
    ("Applications", "2 matches", "ApplicationResourceHistory.qml", "Resource composition and Activity overview / Retained activity. Application actions and Running instances are standalone group labels over commands/window rows, not second card headings."),
    ("Wi-Fi", "2 matches", "NetworkDetailCards.qml; AdvancedSecurityPane.qml; AdvancedIpSettingsPane.qml", "Both diagnostic groups are listed above. Profile settings, Security & privacy and IP & DNS have internal titles only."),
    ("Bluetooth", "No matching pair", "BluetoothAdapterSettings.qml; BluetoothDevicePage.qml; BluetoothInformationPage.qml; BluetoothDeviceAudio.qml", "Technical details in adapter General settings is an external heading over bare fields, without an internally titled card. Device/settings/information cards have internal titles only."),
    ("Clipboard", "No matching pair", "ClipboardDetailCards.qml; ClipboardDetails.qml", "Text/image/file content, Info and recovery cards have internal titles. Files is a label within Info, not an exterior wrapper heading."),
    ("Displays", "No matching pair", "DisplayFocusPane.qml; DisplayInspector.qml; DisplayInformation.qml; DisplayPolicyPane.qml", "Diagnostics is a heading over plain diagnostic text. Restore previous settings repeats an action label, not a card title. Focus categories and display cards have internal titles only."),
    ("Battery", "2 matches", "BatteryCarePane.qml; PowerControlsPane.qml; BatteryProtectionPane.qml; BatterySummaryPane.qml", "Hardware details and Battery levels & hardware tuning are listed above. Charging maintenance is an internal subgroup inside Charging & protection, not an exterior heading above a titled card."),
    ("Activity", "No matching section/card pair", "ActivityContent.qml; ActivitySchedulePane.qml; ActivityAgendaPane.qml; ActivityTodoSection.qml; GlanceScheduleCard.qml", "The selected date appears in the day-navigation bar and agenda card. This is a related repetition, but the outer date belongs to navigation, not a separate section heading. Calendar, agenda and Todos titles are inside their cards."),
    ("Notifications", "No matching pair", "NotificationContent.qml; NotificationSettings.qml; NotificationHistoryRow.qml", "Notification settings labels a plain settings column; there is no second inner card heading. Message summary/application identity is content, not a removable section wrapper."),
    ("Time & Weather", "No matching pair", "TimeWeatherDetails.qml; TimeWeatherTimePane.qml; ActivityWeatherPane.qml; WeatherForecastCard.qml", "Time, sun-position, timezone and forecast labels are within their cards. Repeated city/zone identity in the expanded header is outside this section-heading audit."),
    ("Audio", "No matching pair", "bar/SystemChooserContent.qml (audio branch)", "Output volume is inside its card. Mute output / Mute microphone labels an editable switch, not an exterior section heading."),
    ("Media", "No matching pair", "bar/SystemChooserContent.qml (media branch)", "Now playing is an internal card title. Player preferences is an external group heading over controls with no second card title."),
    ("Tray", "No matching pair", "bar/SystemChooserContent.qml (tray branch)", "Application is an internal card title only."),
]


def esc(value):
    return html.escape(str(value), quote=True)


def build():
    if any(item["external"].split(" / ")[0] not in (ROOT / item["source"]).read_text() for item in ITEMS):
        raise SystemExit("The six headings have been removed. Keep the archived HTML before-pictures; current captures are in target/external-header-removal/.")
    revision = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
    cards = []
    for index, item in enumerate(ITEMS, 1):
        # Fail rather than produce a checklist whose evidence is missing.
        image = (CAPTURES / (item["id"] + ".png")).read_bytes()
        assert image.startswith(b"\x89PNG\r\n\x1a\n")
        assert item["anchor"] in (ROOT / item["source"]).read_text()
        encoded = base64.b64encode(image).decode("ascii")
        inner = " · ".join(item["internal"])
        cards.append(f'''<article class="candidate" id="{esc(item['id'])}">
  <header><span class="eyebrow">{index:02d} / {esc(item['panel'])} · {esc(item['kind'])}</span>
    <h2>{esc(item['external'])}</h2><p class="route">{esc(item['route'])}</p></header>
  <div class="evidence"><figure><img src="data:image/png;base64,{encoded}" width="724"
    alt="{esc(item['external'])} outside the card; {esc(inner)} inside." loading="lazy">
    <figcaption>Current QML rendering · synthetic data · external heading is the top line.</figcaption></figure>
    <div class="explanation"><dl><dt>External heading to decide</dt><dd>{esc(item['external'])}</dd>
      <dt>Internal headings to keep</dt><dd>{esc(inner)}</dd></dl>
      <p>{esc(item['note'])}</p><p><strong>Deletion scope:</strong> {esc(item['preserve'])}</p>
      <p class="source">Source: <code>{esc(item['source'])}:{item['line']}</code></p></div></div>
  <footer><label for="keep-{esc(item['id'])}"><input type="checkbox" id="keep-{esc(item['id'])}" data-choice="{esc(item['id'])}" checked>
    Keep this external heading</label><strong class="decision">KEEP</strong></footer>
</article>''')
    rows = "\n".join(f"<tr><th scope=\"row\">{esc(panel)}</th><td>{esc(result)}</td><td>{esc(note)}<br><small>{esc(source)}</small></td></tr>" for panel, result, source, note in AUDIT)
    metadata = json.dumps(ITEMS, ensure_ascii=False).replace("<", "\\u003c")
    document = TEMPLATE.replace("@@REVISION@@", esc(revision)).replace("@@CARDS@@", "\n".join(cards)).replace("@@AUDIT@@", rows).replace("@@METADATA@@", metadata)
    OUTPUT.write_text(document)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(document.encode()):,} bytes; {len(ITEMS)} embedded images)")


TEMPLATE = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Shelllist · External heading review</title>
<style>
:root { color-scheme: dark; --bg:#111216; --card:#1c1e25; --muted:#b8bac9; --edge:#3d4050; --accent:#d0bcff; --remove:#ffb4ab; }
* { box-sizing:border-box; } body { margin:0; background:var(--bg); color:#f0eef7; font:16px/1.55 system-ui,sans-serif; }
main { max-width:1240px; margin:auto; padding:36px 24px 70px; } h1 { font-size:clamp(28px,4vw,44px); line-height:1.15; margin:12px 0; }
h2 { font-size:24px; margin:5px 0; line-height:1.3; } h3 { font-size:20px; } p { margin:12px 0; } a { color:var(--accent); }
.eyebrow { color:var(--accent); font-size:13px; font-weight:750; letter-spacing:.07em; text-transform:uppercase; }
.intro { max-width:900px; } .muted,.route,figcaption,.source,small { color:var(--muted); } .legend { padding:16px 20px; border-left:4px solid var(--accent); background:#252031; border-radius:0 12px 12px 0; }
.toolbar { display:flex; flex-wrap:wrap; gap:12px; align-items:center; padding:16px 0; } button { font:inherit; border-radius:30px; border:1px solid var(--edge); background:#292b35; color:inherit; padding:10px 18px; cursor:pointer; }
button.primary { background:var(--accent); color:#211536; border-color:transparent; font-weight:700; } button:hover { filter:brightness(1.14); }
:focus-visible { outline:3px solid #e1cbff; outline-offset:4px; } #counts { font-weight:700; } #storage { font-size:14px; color:var(--muted); }
.candidate { border:1px solid var(--edge); border-radius:20px; overflow:hidden; background:var(--card); margin:26px 0; }
.candidate>header { padding:20px 24px 4px; } .route { margin:8px 0; } .evidence { display:grid; grid-template-columns:minmax(0,1.6fr) minmax(240px,1fr); gap:24px; padding:18px 24px 24px; align-items:start; }
figure { margin:0; } img { display:block; width:100%; max-width:724px; height:auto; border-radius:10px; border:1px solid #35333b; }
figcaption { font-size:12px; margin-top:9px; } dl { margin:0; } dt { color:var(--muted); font-size:13px; margin:0 0 4px; } dd { margin:0 0 16px; font-weight:700; }
.source { font-size:12px; overflow-wrap:anywhere; } code { font-family:ui-monospace,monospace; } .explanation p { font-size:14px; }
.candidate footer { padding:16px 24px; border-top:1px solid var(--edge); background:#262330; display:flex; justify-content:space-between; align-items:center; gap:16px; }
label { display:flex; align-items:center; gap:12px; cursor:pointer; font-weight:700; padding:6px 0; } input[type=checkbox] { width:24px; height:24px; accent-color:var(--accent); flex-shrink:0; cursor:pointer; }
.decision { font-size:13px; color:var(--accent); text-align:right; } .candidate.remove { border-color:var(--remove); } .remove .decision { color:var(--remove); } .remove footer { background:#352526; }
details { margin:24px 0; border:1px solid var(--edge); border-radius:14px; padding:18px; } summary { cursor:pointer; font-weight:700; } .table-wrap { overflow-x:auto; } table { width:100%; border-collapse:collapse; margin-top:18px; font-size:14px; }
th,td { text-align:left; vertical-align:top; border-bottom:1px solid var(--edge); padding:14px 10px; } th:first-child { min-width:130px; } td:nth-child(2) { min-width:120px; } small { font-size:12px; }
textarea { display:block; width:100%; min-height:230px; background:#111216; color:inherit; border:1px solid var(--edge); padding:12px; margin-top:14px; font:14px/1.5 ui-monospace,monospace; }
.fine { font-size:13px; color:var(--muted); } noscript p { border:2px solid var(--remove); padding:16px; }
@media(max-width:900px) { .evidence { grid-template-columns:1fr; } main { padding:24px 14px 50px; } .candidate>header,.evidence,.candidate footer { padding-left:16px; padding-right:16px; } }
@media print { :root { color-scheme:light; } body { background:white; color:black; } .toolbar,#storage { display:none; } main { padding:0; } .candidate { break-inside:avoid; background:white; } .evidence { grid-template-columns:1fr; } .candidate footer { background:white; } .muted,.route,figcaption,.source,small,dt { color:#333; } }
</style>
</head>
<body><main>
<header class="intro"><span class="eyebrow">Shelllist / visual decision checklist</span>
<h1>Keep or remove external headings?</h1>
<p><strong>6 matching sections · 3 panels · all 12 registered panels audited.</strong> These sections have a heading outside a card (or group of cards) as well as titles inside. The first is the Wi-Fi example you supplied.</p>
<p class="muted">Scope: section headings, not expanded-panel identity headers, tab names, editable-field labels or card titles. Some entries provide useful grouping rather than repeating the exact same words; those are labelled explicitly.</p>
<div class="legend"><strong>☑ Checked = KEEP the external heading.</strong><br><strong>☐ Unchecked = DELETE only the external heading.</strong><br>Every item starts checked. Cards, internal titles, controls, navigation and data stay. These choices do not change Shelllist.</div>
<p class="fine">Source audit at commit <code>@@REVISION@@</code>. Pictures are fresh offscreen captures of the actual QML sections using synthetic/empty data, not live hardware readings or proposed redesigns. Images are embedded; this file works offline.</p></header>
<noscript><p>JavaScript is disabled: checkbox selection works, but saving, status labels and export do not. Enable JavaScript before making your final choices.</p></noscript>
<div class="toolbar"><button type="button" class="primary" id="export-top">Download choices (.json)</button><button type="button" id="reset">Reset: keep all</button><span id="counts" role="status" aria-live="polite">6 keep · 0 delete</span></div>
<p id="storage" role="status">Choices are stored in this browser when local-file storage is available. Download JSON to reliably save or share them.</p>
<section aria-label="External heading decisions">@@CARDS@@</section>
<section aria-label="Save your decisions"><h2>Finished reviewing?</h2><p>Download your choices and send the JSON file back. It records exactly which external headings to keep or delete. Nothing is uploaded automatically.</p>
<div class="toolbar"><button type="button" class="primary" id="export-bottom">Download choices (.json)</button></div>
<details><summary>Plain-text choices (copy/paste fallback)</summary><label for="text-choices">Current decisions</label><textarea id="text-choices" readonly></textarea></details></section>
<details open><summary>All-panel audit — including headings excluded from this checklist</summary>
<p>The six cards above are the section/card pairs found. The table distinguishes single headings and other repeated text so they are not silently marked for deletion.</p>
<div class="table-wrap"><table><thead><tr><th>Panel</th><th>Result</th><th>Coverage / exclusions</th></tr></thead><tbody>@@AUDIT@@</tbody></table></div></details>
<p class="fine">Implementation note for later: remove only the chosen heading and its surplus spacing, not its section container. Preserve <code>informationOnly</code>, object identity, card titles, state information and existing keyboard/save semantics. This is a review document, not approval to change any panel.</p>
</main>
<script id="review-data" type="application/json">@@METADATA@@</script>
<script>
'use strict';
const items = JSON.parse(document.getElementById('review-data').textContent);
const key = 'shelllist.external-heading-review.v1.@@REVISION@@';
const boxes = [...document.querySelectorAll('input[data-choice]')];
const storageStatus = document.getElementById('storage');
let storageAvailable = true;
function choices() {
  return items.map(item => ({...item, decision: document.getElementById('keep-' + item.id).checked ? 'keep' : 'delete'}));
}
function update(persist) {
  const decisions = choices();
  const keep = decisions.filter(item => item.decision === 'keep').length;
  document.getElementById('counts').textContent = `${keep} keep · ${items.length - keep} delete`;
  for (const box of boxes) {
    const card = document.getElementById(box.dataset.choice);
    card.classList.toggle('remove', !box.checked);
    card.querySelector('.decision').textContent = box.checked ? 'KEEP' : 'DELETE EXTERNAL HEADING';
  }
  document.getElementById('text-choices').value = 'Shelllist external heading decisions (@@REVISION@@)\nOnly external headings; retain internal titles and controls.\n\n' + decisions.map(item => `${item.decision.toUpperCase()} | ${item.panel} | ${item.external}\n  ${item.source}:${item.line}`).join('\n\n');
  if (persist && storageAvailable) {
    try {
      localStorage.setItem(key, JSON.stringify(Object.fromEntries(boxes.map(box => [box.dataset.choice, box.checked]))));
      storageStatus.textContent = 'Choices saved in this browser. Download JSON to share them or keep a portable copy.';
    } catch (_) {
      storageAvailable = false;
      storageStatus.textContent = 'Browser storage is unavailable. Download JSON or copy the text summary before closing this page.';
    }
  }
}
try {
  const saved = JSON.parse(localStorage.getItem(key) || '{}');
  if (saved && typeof saved === 'object') {
    for (const box of boxes) if (typeof saved[box.dataset.choice] === 'boolean') box.checked = saved[box.dataset.choice];
  }
} catch (_) {
  storageAvailable = false;
  storageStatus.textContent = 'Saved choices could not be read. All headings start kept; download JSON to preserve your selections.';
}
for (const box of boxes) box.addEventListener('change', () => update(true));
document.getElementById('reset').addEventListener('click', () => {
  if (!window.confirm('Reset all six choices to KEEP?')) return;
  for (const box of boxes) box.checked = true;
  update(true);
});
function download() {
  const payload = {schema: 'shelllist-external-heading-review-v1', sourceRevision: '@@REVISION@@', exportedAt: new Date().toISOString(), scope: 'External heading only; retain internal headings, controls and section semantics', choices: choices()};
  const url = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2) + '\n'], {type:'application/json'}));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'shelllist-external-heading-choices.json';
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
document.getElementById('export-top').addEventListener('click', download);
document.getElementById('export-bottom').addEventListener('click', download);
update(false);
</script></body></html>
'''

if __name__ == "__main__":
    build()
