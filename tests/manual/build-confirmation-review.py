#!/usr/bin/env python3
"""Build the self-contained confirmation proposal from actual Qt review captures.

Historical before-change proposal builder. The approved HTML embeds its images;
browser feedback is local and can be exported/imported as JSON. Refuse to replace
that archive from post-implementation sources/captures.
"""
import base64
import datetime
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "target/confirmation-review"
OUTPUT = ROOT / "docs/reviews/confirmation-review.html"
REFERENCE = Path("/home/laufan/Pictures/Screenshots/clipboard-history/clipboard-cc8b92f7-ebc6-4cf4-9ea0-4fe5079252b6.png")


def image(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def variant(id, label, title, detail, **kwargs):
    return dict(id=id, label=label, title=title, detail=detail, **kwargs)


def item(id, panel, title, category, recommendation, source, reason, guards, variants):
    return dict(id=id, panel=panel, title=title, category=category,
                recommendation=recommendation, source=source, reason=reason,
                guards=guards, variants=variants)


ITEMS = [
    item("clipboard-single", "Clipboard", "Delete one entry", "confirmation", "keep",
         "clipboard/ClipboardContent.qml:115–127 · Ui.ConfirmationDialog",
         "Already compact: the actions share one line, and the duplicate action summary and consequence paragraph are gone. Keep this rather than restyling a screen that already converged. The keyboard hint is an existing deliberate choice, not a new requirement.",
         "Cancel initially focused; deletion only after explicit confirmation; permanent-removal consequence stays accessible. Preserve selected-entry/revision and busy guards.",
         [variant("clipboard-single", "Single entry", "Delete clipboard entry?", "")]),
    item("clipboard-bulk", "Clipboard", "Delete selected entries", "confirmation", "change",
         "clipboard/ClipboardContent.qml:128–136 · Ui.ConfirmationDialog",
         "Match the supplied single-delete target: question icon, one short question, then Cancel and Delete together at the right. Remove the consequence paragraph and repeated action labels. Keep the existing compact keyboard hint.",
         "Only the captured selected IDs/revisions are deleted. Keep count pluralization, busy guards and native modal focus/cancel behavior.",
         [variant("clipboard-bulk", "3 selected", "Delete 3 clipboard entries?", "Only the selected entries will be permanently removed.", accept="Delete selected", tone="danger"),
          variant("clipboard-bulk-one", "1 selected", "Delete 1 clipboard entry?", "Only the selected entry will be permanently removed.", accept="Delete selected", tone="danger")]),
    item("clipboard-wipe", "Clipboard", "Clear all history", "confirmation", "change",
         "clipboard/ClipboardContent.qml:137–145 · ClipboardController.confirmWipe",
         "Use only “Clear all clipboard history?” beside the right-aligned Cancel/Clear controls. Remove the explanatory paragraph. The full wipe scope remains in the accessible description and backend challenge, not extra visible copy.",
         "Retain the daemon-issued wipe challenge and commit boundary. No ordinary editor save or passive message dismiss may clear history.",
         [variant("clipboard-wipe", "All history", "Clear all clipboard history?", "Regular entries, favorites and generated previews will be permanently removed.", accept="Clear all", tone="danger")]),
    item("notifications", "Notifications", "Delete notifications", "confirmation", "change",
         "activity/NotificationContent.qml:114–123 · NotificationState.prepareDelete / confirmDelete",
         "One short count/scope question, with Cancel immediately left of Delete on the right. Remove the explanation below it and fix “1 notifications”. All three scopes share the same compact composition.",
         "Keep the native snapshot token, expiry check, cancellation/release and no optimistic removal. Later arrivals survive; app preferences survive. Never replay deletion automatically.",
         [variant("notifications-one", "One notification", "Delete this notification?", "“Meeting reminder” will be permanently removed. App preferences are unchanged.", accept="Delete", tone="danger"),
          variant("notifications-app", "One app · 12", "Delete 12 Mail notifications?", "Includes retained notifications outside this search. App preferences stay unchanged. This cannot be undone.", accept="Delete", tone="danger"),
          variant("notifications-all", "All apps · 47", "Delete all 47 notifications?", "Includes retained notifications outside this search. App preferences stay unchanged. This cannot be undone.", accept="Delete all", tone="danger")]),
    item("bluetooth-forget", "Bluetooth", "Forget a device", "confirmation", "change",
         "bluetooth/BluetoothContent.qml:38–46 · BluetoothProvider.qml:73–90",
         "Keep the target’s question tile and inline right-hand controls. Show only “Forget Studio headphones?”; remove the pairing/trust paragraph and duplicated command labels.",
         "Keep the pending action identity, capability/busy checks and cancellation when the selected device changes. Forget remains explicit, never triggered by browsing.",
         [variant("bluetooth-forget", "Forget device", "Forget Studio headphones?", "Pairing information and saved trust will be deleted.", accept="Forget", tone="danger")]),
    item("bluetooth-compare", "Bluetooth", "Compare a pairing code", "confirmation", "change",
         "bluetooth/BluetoothPairingPrompt.qml · kind: confirmation",
         "Put one short code-match question and Reject/Confirm in the target header layout. Keep the actual code below as essential verification data; remove the separate instruction paragraph and repeated command labels.",
         "Keep request identity, pending-response disabling, explicit accept/reject and code equality being checked by the user. No automatic trust.",
         [variant("bluetooth-confirmation", "Code comparison", "Code matches Studio headphones?", "Verify the code shown on Studio headphones before confirming.", code="482019", accept="Confirm match", reject="Reject")]),
    item("bluetooth-authorize", "Bluetooth", "Allow pairing", "confirmation", "change",
         "bluetooth/BluetoothPairingPrompt.qml · kind: authorization",
         "Use a single question naming the device, then Reject/Allow at the right. Keep the question tile. Remove the explanation underneath and the repeated action labels.",
         "Keep response-required and pending guards. Reject/cancel remains a negative response to the same request.",
         [variant("bluetooth-authorization", "Pairing permission", "Pair with Studio headphones?", "Studio headphones wants to pair with this computer.", accept="Allow pairing", reject="Reject")]),
    item("bluetooth-service", "Bluetooth", "Allow a Bluetooth service", "confirmation", "change",
         "bluetooth/BluetoothPairingPrompt.qml · kind: service-authorization",
         "Ask one short service-permission question with Reject/Allow on the right. Remove the paragraph and visible UUID block; keep the full requesting device and service identifier in the accessible description. This changes presentation, not permission scope.",
         "Keep the same request and requested service. Do not broaden permission or remember approval implicitly.",
         [variant("bluetooth-service-authorization", "Service permission", "Allow headphones’ Audio Sink?", "Studio headphones is requesting Audio Sink access.", metadata="0000110b-0000-1000-8000-00805f9b34fb", accept="Allow service", reject="Reject")]),
    item("bluetooth-input", "Bluetooth", "Enter a PIN or passkey", "input", "change",
         "bluetooth/BluetoothPairingPrompt.qml · kinds: pin-code, passkey",
         "Related required-input screens: use the same compact header and right-hand Reject/Confirm pair. Remove the explanatory paragraph; retain the required PIN/passkey field. The field in this illustration is inert.",
         "PIN maximum 16 characters; passkey 1–6 digits; masked inputs; pending guard; native contained Tab and explicit submit/cancel. Never persist secrets in review or panel memory.",
         [variant("bluetooth-pin-code", "PIN", "Enter the device PIN", "Provide the PIN requested by Studio headphones.", field="PIN", placeholder="Required · up to 16 characters", accept="Confirm", reject="Reject", disabled=True),
          variant("bluetooth-passkey", "Passkey", "Enter the device passkey", "Provide the passkey requested by Studio headphones.", field="Passkey", placeholder="Required · 1–6 digits", accept="Confirm", reject="Reject", disabled=True)]),
    item("bluetooth-display", "Bluetooth", "Show a code on the remote device", "waiting", "change",
         "bluetooth/BluetoothPairingPrompt.qml · kinds: display-pin, display-passkey",
         "Related waiting screens, not confirmations. Remove the extra waiting sentence; retain the device instruction, actual code and supplied digit progress. Do not invent local approval buttons for a remote-owned step.",
         "These modes have response_required=false. Do not add a Confirm/Reject action or enable Escape rejection; preserve daemon-owned completion.",
         [variant("bluetooth-display-pin", "Display PIN", "Enter this code on Studio headphones", "Waiting for the remote device…", code="482019", passive=True),
          variant("bluetooth-display-passkey", "Display passkey", "Enter this code on Studio headphones", "3 of 6 digits entered · waiting for the remote device…", code="482019", passive=True)]),
    item("wifi-forget", "Wi-Fi", "Forget a saved network", "confirmation", "change",
         "wifi/WifiContent.qml:50–70 · WifiPromptController.submitForget · WifiPromptPolicy.forgetCopy",
         "Use one network question with Cancel/Forget in the header’s right-hand pair. Remove the profile/session explanation. Keep the required typed challenge below, clearly labeled Type FORGET; this is still not a one-click operation.",
         "Keep the existing trimmed, case-insensitive FORGET validation and captured network/profile target. Do not send a mutation before valid explicit submission; preserve cancel and connection guards.",
         [variant("wifi-forget", "Saved · inactive", "Forget Home network?", "Remove 1 saved profile: Home network. The hotspot may still recognize this device until its login session expires.", field="Type FORGET", placeholder="FORGET", accept="Forget", tone="danger", disabled=True),
          variant("wifi-disconnect-forget", "Currently connected", "Disconnect & forget Home network?", "Disconnect from this network and remove 1 saved profile: Home network. The hotspot may still recognize this device until its login session expires.", field="Type FORGET", placeholder="FORGET", accept="Disconnect & forget", tone="danger", disabled=True)]),
    item("battery-calibrate", "Battery & Power", "Start calibration", "confirmation", "change",
         "battery/BatteryContent.qml:61–79 · pendingReview: calibration",
         "Show only “Calibrate battery?” beside the Cancel/Calibrate controls. Remove the duration, power-supply and cancellation explanation from the visible dialog. Retain that information in the accessible description and keep all capability/AC guards.",
         "Recheck captured battery identity, AC power, calibration support and busy/threshold guards on acceptance. Changing device or closing the panel cancels the review. Cancelling an already running calibration remains direct.",
         [variant("battery-calibration", "Start calibration", "Calibrate battery?", "May discharge and recharge for several hours. Keep the power supply connected. Cancel calibration from Charging actions.", accept="Calibrate")]),
    item("battery-critical", "Battery & Power", "Enable critical-battery hibernation", "confirmation", "change",
         "battery/BatteryContent.qml:61–79 · pendingReview: critical",
         "Show only “Enable critical-battery hibernation?” with Cancel/Enable on the right. Remove the visible prerequisite/explanation paragraph; retain its accessible description and all existing policy and safety checks.",
         "Keep service readiness, policy-saving and in-flight guards. Explicit approval still submits the policy update; disabling the policy remains direct.",
         [variant("battery-critical", "Enable policy", "Enable critical-battery hibernation?", "Use only one automatic power manager and verify that hibernation works. A warning period comes first; locking and inhibitors remain enforced.", accept="Enable")]),
    item("display-trial", "Displays", "Keep a previewed layout", "confirmation", "keep",
         "displays/DisplayTrialDialog.qml · DisplayController.displayLayoutAction",
         "Already matches the target’s one-question header and right-aligned Revert/Keep pair. Keep it. The countdown remains functional trial data, not explanatory prose.",
         "Initial Revert focus; daemon timeout/rollback; stale topology and expired trial block Keep. Keep existing native Tab/Enter action routes and backend checks.",
         [variant("display-trial", "20-second trial", "Keep this layout?", "")]),
    item("display-discard", "Displays", "Leave a dirty layout", "confirmation", "change",
         "displays/DisplayContent.qml:36–53 · discardDisplayDraft",
         "Show only “Discard layout changes?” with Keep editing immediately left of Discard, both on the right. Remove repeated action labels; do not add a consequence paragraph. Use an undo glyph for Discard. Keep editing stays the safe default.",
         "Do not enable the generic Enter-to-accept shortcut: enterEnabled stays false. Preserve explicit focused-button activation, Escape returning to editing and local-draft-only discard.",
         [variant("display-discard", "Dirty layout", "Discard layout changes?", "Only your unpreviewed layout changes will be discarded.", accept="Discard", reject="Keep editing", tone="warning", icon="undo", hint="Esc keep editing")]),
    item("clipboard-menu", "Clipboard", "Delete-scope chooser", "menu", "keep",
         "clipboard/ClipboardContent.qml:67–114 · Ui.PromptDialog / ActionToggleList",
         "Related scope menu, not a confirmation question. Keep its three choices unchanged. Only the subsequent confirmation dialogs adopt the supplied target.",
         "Keep selection/availability guards and each option’s existing route. Opening this menu must not delete anything.",
         [variant("clipboard-menu", "Scope menu", "Delete clipboard entries", "")]),
    item("applications-empty", "Applications", "Empty states — outside this redesign", "reference", "keep",
         "launcher/ApplicationPage.qml · current working-tree empty-window / no-desktop-action branches",
         "The corrected target is the compact Clipboard confirmation, not the earlier Applications screenshot. Withdraw the previous proposal to restore empty-state text. Leave these passive icons unchanged; Applications has no confirmation dialog to restyle.",
         "No added commands or field stops; Launch remains available. Keep app-data availability distinct from zero and do not imply that a close request has completed before authoritative observation.",
         [variant("applications-empty", "Both empty states", "No open windows", "Use Launch beside the application name to get started.", passive=True, application=True)])
]

if "compactPresentation: true" in (ROOT / "qml/Shelllist/Ui/ConfirmationDialog.qml").read_text():
    raise SystemExit("The proposal is an approved before-change archive. Do not overwrite it from implemented sources. Use tst_confirmation_review.qml for after captures.")

for entry in ITEMS:
    for v in entry["variants"]:
        stem = v["id"]
        v["current"] = image(CAPTURES / (stem + ("-context" if stem == "applications-empty" else "") + ".png"))
        v["context"] = image(CAPTURES / (stem + "-context.png"))

metadata = dict(head=subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip(),
                generated=datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
                reference=image(REFERENCE), items=ITEMS)

TEMPLATE = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shelllist · confirmation review</title>
<style>
:root{color-scheme:dark;--bg:#101216;--surface:#191d22;--soft:#232830;--line:#343b46;--text:#e4e8ef;--muted:#b3bdcc;--blue:#aecbfa;--green:#b1d7bd;--orange:#efb965;--red:#ffb4ac}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 system-ui,sans-serif}a{color:var(--blue)}button,input,textarea,select{font:inherit}button,select{color:var(--text);background:var(--soft);border:1px solid var(--line);border-radius:9px;padding:9px 13px}button{cursor:pointer}button:hover{border-color:var(--blue)}:focus-visible{outline:3px solid var(--blue);outline-offset:3px}textarea,input[type=search]{background:#11151b;border:1px solid #485260;color:var(--text);border-radius:8px;padding:11px;width:100%}textarea{resize:vertical;min-height:92px}h1,h2,h3,p,figure{margin-top:0}h1{font-size:clamp(30px,4vw,52px);line-height:1.12;letter-spacing:-1.5px;margin-bottom:18px}h2{font-size:23px;line-height:1.3}h3{font-size:15px}.eyebrow{text-transform:uppercase;letter-spacing:2px;color:var(--blue);font-size:12px;font-weight:700}.muted,small{color:var(--muted)}.wrap{max-width:1460px;margin:auto;padding:32px}.intro{display:grid;grid-template-columns:1.4fr 1fr;gap:38px;padding:28px 0 10px}.lead{font-size:18px;color:var(--muted);max-width:65ch}.stats{display:flex;gap:10px;flex-wrap:wrap;margin:25px 0}.pill,.tag{border:1px solid var(--line);border-radius:20px;padding:5px 11px;font-size:12px}.pill strong{color:var(--blue)}.reference-image{width:100%;border-radius:15px;display:block}.image-button{border:0;padding:0;background:transparent;width:100%;text-align:left}.image-button:hover{opacity:.93}figcaption{font-size:12px;color:var(--muted);margin-top:9px}figure{margin:0}.note{border-left:3px solid var(--blue);padding:12px 17px;background:#1c2330;border-radius:0 10px 10px 0}.note p:last-child{margin:0}.toolbar{position:sticky;top:0;z-index:5;background:#101216f5;backdrop-filter:blur(12px);padding:14px 0;border-block:1px solid var(--line);display:flex;flex-wrap:wrap;align-items:center;gap:10px}.toolbar input{width:240px;flex:1;min-width:170px}.toolbar label{font-size:13px}.toolbar .primary{background:#b9cff0;color:#142238}.progress{margin-left:auto;font-size:13px;color:var(--green)}.save-note{font-size:12px;padding:9px 0;color:var(--muted)}.layout{display:grid;grid-template-columns:210px minmax(0,1fr);gap:28px}nav{position:sticky;top:110px;align-self:start;max-height:calc(100vh - 140px);overflow:auto;padding-top:12px}nav a{display:block;padding:6px 9px;text-decoration:none;font-size:13px;color:var(--muted);border-left:2px solid transparent}nav a:hover{background:var(--soft);color:var(--blue);border-color:var(--blue)}nav b{display:block;margin:18px 8px 4px;font-size:12px;color:var(--blue);text-transform:uppercase;letter-spacing:.8px}.review-card{border:1px solid var(--line);background:#171b20;border-radius:18px;margin:24px 0;padding:24px;scroll-margin-top:140px}.review-card[data-decision=approved]{border-color:#587461}.review-card[data-decision=changes]{border-color:#967749}.review-card[data-decision=rejected]{border-color:#97646a}.card-top{display:flex;justify-content:space-between;align-items:flex-start;gap:14px}.card-top h2{margin-bottom:7px}.number{color:var(--muted);font-weight:400}.tag{white-space:nowrap;text-transform:uppercase;letter-spacing:1px;font-size:10px}.tag.change{color:var(--orange)}.tag.keep{color:var(--green)}.source{font:12px/1.6 ui-monospace,monospace;color:#a2acbb;overflow-wrap:anywhere;margin-bottom:16px}.reason{color:#c9d0dc;font-size:14px}.variants{display:flex;gap:7px;flex-wrap:wrap;margin:16px 0}.variants button{padding:6px 10px;font-size:12px}.variants button[aria-pressed=true]{background:#35435a;border-color:#8facd9}.comparison{display:grid;grid-template-columns:1fr 1fr;gap:18px;margin:18px 0}.visual{min-width:0}.visual-title{font-size:11px;letter-spacing:1px;text-transform:uppercase;color:var(--muted);margin-bottom:10px}.stage{background:#0f1217;min-height:260px;border-radius:12px;padding:14px;display:flex;align-items:center;justify-content:center;position:relative;border:1px solid #2b313b}.current-image{display:block;width:100%;height:auto;max-height:480px;object-fit:contain}.context{font-size:12px;background:none;border:0;padding:8px 0;color:var(--blue);text-decoration:underline}.mock{width:100%;background:#191d22;color:#dce1e9;border:1px solid #8ca9d0;border-radius:28px;padding:20px 16px 16px;font-family:'Roboto Flex',system-ui,sans-serif}.mock-header{display:grid;grid-template-columns:48px minmax(0,1fr) auto;align-items:center;gap:12px}.question-tile{width:48px;height:48px;display:grid;place-items:center;border:1px solid #9bb8df;border-radius:8px;background:#3b4658;color:#c8d0dd;font-size:24px}.question-tile svg{width:24px;height:24px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round}.mock-title{font-size:18px;font-weight:700;line-height:1.25;margin:0;overflow-wrap:anywhere}.mock-actions{display:flex;gap:8px;align-items:center;justify-content:flex-end}.mock-command{display:block}.circle{height:44px;width:44px;border-radius:50%;background:#30343b;color:#dce1e9;border:1px solid #687181;display:grid;place-items:center;position:relative}.mock-command:not(.affirm) .circle:before{content:'';position:absolute;left:3px;top:17px;width:3px;height:10px;background:#adcfff;border:1px solid #171b21;border-radius:2px}.circle svg{width:22px;height:22px;fill:none;stroke:currentColor;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}.affirm .circle{width:52px;height:52px;background:#a6c8ff;color:#153354;border:0}.affirm.danger .circle{background:#ffb4ac;color:#5f1719}.affirm.warning .circle{background:#efc578;color:#442b00}.disabled .circle{background:#34383f;color:#9299a3}.mock-hint{text-align:center;font-size:12px;color:#bfc7d4;margin:28px 0 0}.mock-progress{text-align:center;font-size:13px;color:#bfc7d4;margin:8px 0 0}.mock-code{text-align:center;font-size:32px;letter-spacing:5px;color:#b7cfff;line-height:1.4;margin:15px 0;font-weight:650}.mock-metadata{font:12px/1.5 ui-monospace,monospace;color:#c6cedb;overflow-wrap:anywhere;margin-top:12px;text-align:center}.mock-field{display:grid;grid-template-columns:100px minmax(0,1fr);align-items:center;gap:12px;margin-top:20px;border-bottom:1px solid #424953;padding-bottom:8px;font-size:14px}.fake-input{min-height:38px;padding:9px 4px;font-size:13px;color:#aeb9c9;border-bottom:2px solid #95b9eb;overflow-wrap:anywhere}.mock-caption{font-size:11px;color:var(--muted);margin-top:8px}.mock-app{background:#101318;padding:0}.mock-app .message{background:#1c2025;border-radius:16px;padding:24px 14px}.mock-data{padding:18px;background:#191d22;margin-top:12px;border-radius:16px;font-size:13px}.mock-data dl{display:grid;grid-template-columns:1fr 1fr;margin-bottom:0;gap:10px;font-size:12px;color:#bfc7d4}.mock-data dd{margin:2px 0 0}.mock-foot{font-size:13px;color:#bfc7d4;margin:12px 0 0}.safety{font-size:13px;background:#202731;padding:12px 15px;border-radius:10px}.safety strong{color:var(--blue)}.decision-box{margin-top:18px;border-top:1px solid var(--line);padding-top:18px}.decision-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:12px}.decision-row label{font-size:13px}.decision-row select{min-width:210px}.decision-status{font-size:12px;color:var(--muted)}.comment-label{display:block;font-size:13px;margin-bottom:6px}.direction{margin-top:20px}.scope{margin:24px 0;padding:22px;background:#1a2028;border-radius:14px}.scope summary{cursor:pointer;font-size:17px;font-weight:600}.scope table{width:100%;border-collapse:collapse;margin-top:18px;font-size:13px}.scope th,.scope td{padding:10px 8px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}.scope th{color:var(--blue)}.scope code{font-size:12px}.empty{padding:30px;text-align:center}footer{margin:28px 0;color:var(--muted);font-size:12px}.hidden,[hidden]{display:none!important}dialog{max-width:min(1300px,96vw);max-height:94vh;background:#151a20;border:1px solid #7186a6;color:var(--text);border-radius:15px;padding:16px}dialog::backdrop{background:#000c}dialog img{display:block;max-width:100%;max-height:78vh;object-fit:contain;margin:auto}dialog .dialog-head{display:flex;justify-content:space-between;gap:20px;align-items:center;margin-bottom:12px}.dialog-head p{margin:0;font-size:13px}.toast{position:fixed;bottom:22px;right:22px;z-index:20;background:#d1e1f7;color:#162435;padding:12px 18px;border-radius:10px;max-width:90vw}.global-comment{margin-top:16px}.download-hint{color:var(--orange)}
@media(min-width:1500px){.stage{min-height:280px}}@media(max-width:1100px){.layout{grid-template-columns:1fr}nav{display:none}.wrap{padding:22px}.intro{gap:25px}.stage{padding:10px}.review-card{padding:20px}}@media(max-width:720px){.intro,.comparison{grid-template-columns:1fr}.intro figure{max-width:500px}.toolbar{position:static}.review-card{padding:16px}.wrap{padding:14px}.card-top{flex-wrap:wrap}.stage{min-height:200px}.progress{width:100%;margin:0}.source{font-size:11px}.scope{overflow:auto}.review-card{scroll-margin-top:16px}h1{letter-spacing:-.8px}.mock-field{grid-template-columns:90px minmax(0,1fr)}.mock-header{grid-template-columns:36px minmax(0,1fr) auto;gap:8px}.question-tile{width:36px;height:40px}.mock-title{font-size:16px}.mock-actions{gap:6px}.circle{width:36px;height:36px}.affirm .circle{width:44px;height:44px}.mock-command:not(.affirm) .circle:before{top:13px}}
@media print{.toolbar,nav,.save-note,.variants,.context,footer{display:none}.layout{display:block}.review-card{break-inside:avoid}.wrap{padding:0}.comparison{grid-template-columns:1fr 1fr}body{-webkit-print-color-adjust:exact;print-color-adjust:exact}textarea{height:auto}.intro{grid-template-columns:1.4fr 1fr}}
</style></head><body>
<div class="wrap">
<header class="intro"><div><p class="eyebrow">Shelllist / review revision 2 / not implemented</p><h1>One short question.<br>Cancel, then approve.</h1><p class="lead">Every confirmation follows your compact Clipboard target: the question on the left, both actions together on the right, and no explanatory paragraph.</p><div class="stats"><span class="pill"><strong>6</strong> panels with confirmations</span><span class="pill"><strong>23</strong> captured states</span><span class="pill"><strong>17</strong> review items</span></div><p class="note"><strong>Corrected target:</strong> keep the question icon, inline Cancel/Approve placement and compact keyboard hint. Remove extraneous explanation and repeated labels. Required inputs, pairing codes and the display countdown remain.</p><p class="muted">Current Qt screenshots are unchanged; the proposed replacements below are revised. Nothing changes the running shell. The previous Applications empty-state proposal is withdrawn.</p></div><figure><button class="image-button" id="reference-open" aria-label="Enlarge your target screenshot"><img class="reference-image" id="reference-image" alt="Target compact confirmation: question icon, Delete clipboard entry?, Cancel immediately left of Delete on the right, and a small keyboard hint"></button><figcaption>Your corrected target · click to enlarge. This exact single-delete dialog is the model for the replacements.</figcaption></figure></header>
<section class="review-card direction" id="direction"><div class="card-top"><div><p class="eyebrow">Decision 00 / shared direction</p><h2>Match this composition, not just its colours</h2></div><span class="tag change">Revised direction</span></div><p><strong>One header row:</strong> question icon → short question → Cancel → Approve. Both icon-only actions stay together at the right, on the same row as the question. No centered button row underneath, no action captions, no repeated action summary, no consequence paragraph. Keep the compact keyboard hint shown in the target.</p><p class="muted">Codes, required fields and the automatic-revert countdown are functional data, not explanation. Keep those where needed. Removed explanations remain in accessible descriptions; request ownership, validation, cancellation and safety guards do not change.</p><p class="muted">Revision 2 starts a fresh set of approvals so old decisions cannot silently approve different designs. Old browser data is not overwritten; <a href="confirmation-review-v1.html">the previous design is archived separately</a>.</p><div id="direction-decision"></div></section>
<div class="toolbar" aria-label="Review tools"><input id="search" type="search" placeholder="Find a panel or confirmation…" aria-label="Filter by text"><label for="filter">Show</label><select id="filter"><option value="all">All decisions</option><option value="pending">Not reviewed</option><option value="approved">Approved</option><option value="changes">Changes requested</option><option value="rejected">Rejected</option><option value="keep">Recommended: keep</option><option value="confirmation">Confirmations only</option></select><button class="primary" id="export">Export decisions</button><button id="import">Import decisions</button><input id="import-file" type="file" accept="application/json,.json" hidden><span class="progress" id="progress" aria-live="polite"></span></div>
<div class="save-note" id="save-note" role="status">Feedback stays in this browser. Export JSON to share decisions or keep a portable backup; the HTML file itself is not rewritten.</div>
<div class="layout"><nav id="nav" aria-label="Review inventory"></nav><main><div id="cards"></div><p id="no-matches" class="empty" hidden>No items match this filter.</p>
<details class="scope" id="coverage"><summary>Coverage, exclusions & implementation boundaries</summary><p class="muted">All production QML/JS prompt and confirmation call sites were searched in this checkout. Variants share existing components; “23 captures” does not mean 23 independent dialogs. Current means the working tree, including pre-existing uncommitted changes, not just HEAD.</p><table><thead><tr><th>Panel</th><th>Inventory / exclusions</th></tr></thead><tbody>
<tr><td>Clipboard</td><td>Single delete; selected delete (one/many); full wipe; related scope chooser. All captured.</td></tr>
<tr><td>Notifications</td><td>Record / app / global deletion through one native-token confirmation. All three scopes captured.</td></tr>
<tr><td>Bluetooth</td><td>Forget; code comparison; pairing authorization; service authorization; PIN/passkey input; display-only PIN/passkey. All seven pairing kinds plus Forget captured. “Complete pairing” is the shared fallback heading, not an additional known request kind.</td></tr>
<tr><td>Wi-Fi</td><td>Forget saved network; disconnect & forget active network. Both captured. Password, enterprise, hidden-network and daemon-secret forms are credentials, not confirmation screens; QR sharing is information. They retain their existing shared form/modal behavior and are not redesigned here.</td></tr>
<tr><td>Battery & Power</td><td>Start calibration; enable critical-battery hibernation. Both captured. Suspend, hibernate, lock, calibration cancellation and disabling critical protection have no additional Shelllist confirmation screen.</td></tr>
<tr><td>Displays</td><td>Keep/Revert trial; discard local changes. Both captured. Stale/error/expired trial messages are states of that dialog, not separate prompts; their guards remain.</td></tr>
<tr><td>Applications</td><td>No Shelllist confirmation modal. Window Close and application actions retain their existing guards; an application’s own unsaved-document dialog is outside Shelllist. The earlier empty-state redesign proposal is withdrawn; keep those icons unchanged.</td></tr>
<tr><td>Activity</td><td>No Shelllist confirmation modal found. Todo delete remains its existing direct action; no new confirmation proposed.</td></tr>
<tr><td>Time & Weather</td><td>No Shelllist confirmation modal found; no new confirmation invented.</td></tr>
<tr><td>Audio / Media / Tray</td><td>No Shelllist-owned confirmation modal found. Native third-party tray menus or external app prompts are not owned by this review.</td></tr>
<tr><td>Shell / bar / portal launcher</td><td>No additional Shelllist confirmation screen found. Toasts, OSD, status messages, Polkit/system prompts and browser portal pages are not approval dialogs in these components.</td></tr>
</tbody></table><h3 style="margin-top:20px">Implementation if approved</h3><p>Share the target’s compact inline-header composition through <code>qml/Shelllist/Ui/ModalFrame.qml</code>, <code>PromptDialog.qml</code> and <code>ConfirmationDialog.qml</code>, with an explicit compact option rather than unconditionally restyling every required-input dialog. No panel-local keyboard model. Keep <code>FieldRow</code> labels left of editors. Ordinary field Tab/Enter/Escape transactions remain unchanged; required-input modals keep their existing contained native traversal.</p><p>If operation feedback is redesigned later, use shared <code>FeedbackSource</code> composition. This review does not add expanding status rows or require mandatory status-bar visibility. Backend acknowledgement, request ownership, validation, retry and safety remain domain-owned.</p><p><strong>Evidence gate:</strong> after implementation, update the interaction contract and actual Qt consumer tests for focus restoration, cancellation, no pre-approval writes, stale/expired requests, typed challenges, code validation and rollback. Add normal/minimum, long-title and light-theme captures. Current evidence is dark-theme Qt 6.11.1 software/offscreen rendering with synthetic state and recording transports—not real hardware acceptance, screen-reader testing or live destructive operations.</p><p><strong>Target fidelity:</strong> question tile and short question on the left; Cancel then Approve together at the right; no consequence paragraph, repeated action labels or button captions. The existing compact keyboard hint is retained, without inventing unsafe Enter shortcuts. Required fields, pairing codes and the trial countdown are functional exceptions, not extra explanation. Removed explanations remain accessible; validation, acknowledgement and safety guards are unchanged.</p></details>
<section class="scope"><h2>Overall comments</h2><label class="comment-label" for="global-comment">Anything missing, a different interpretation of the reference, or rollout priorities?</label><textarea id="global-comment" placeholder="Any exceptions to the one-question layout, or changes to a proposed question?"></textarea><p class="download-hint" style="margin-top:12px;margin-bottom:0">When finished, export the decisions JSON and send it back with this HTML’s name. Browser autosave alone does not share your approvals.</p></section>
<footer id="provenance"></footer></main></div></div>
<dialog id="viewer"><div class="dialog-head"><p id="viewer-title"></p><button id="viewer-close" aria-label="Close enlarged screenshot">Close ×</button></div><img id="viewer-image" alt=""></dialog><div class="toast" id="toast" role="status" hidden></div>
<script id="review-data" type="application/json">__DATA__</script>
<script>
'use strict';
const data=JSON.parse(document.getElementById('review-data').textContent);
const KEY='shelllist-confirmation-review-v2', SCHEMA=2;
const $=id=>document.getElementById(id);
const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const states=['pending','approved','changes','rejected'];
const known=['direction',...data.items.map(i=>i.id)];
let feedback={schema:SCHEMA,review:KEY,decisions:{},overall:''}, storageAvailable=true, saveTimer;
function normalize(raw){
 if(!raw||raw.schema!==SCHEMA||raw.review!==KEY||!raw.decisions||typeof raw.decisions!=='object')throw Error('Use a revision-2 confirmation review export. Earlier approvals do not apply to these revised proposals.');
 const clean={schema:SCHEMA,review:KEY,decisions:{},overall:typeof raw.overall==='string'?raw.overall:''};
 for(const id of known){const entry=raw.decisions[id];if(entry&&states.includes(entry.status))clean.decisions[id]={status:entry.status,comment:typeof entry.comment==='string'?entry.comment:'',updated:typeof entry.updated==='string'?entry.updated:''};}
 return clean;
}
try{const saved=localStorage.getItem(KEY);if(saved)feedback=normalize(JSON.parse(saved));}catch(e){storageAvailable=false;}
function entry(id){return feedback.decisions[id]||{status:'pending',comment:'',updated:''};}
function announce(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(saveTimer);saveTimer=setTimeout(()=>$('toast').hidden=true,4500);}
function persist(){
 try{localStorage.setItem(KEY,JSON.stringify(feedback));storageAvailable=true;}catch(e){storageAvailable=false;}
 $('save-note').textContent=storageAvailable?'Saved locally in this browser. Export JSON to share or back up; moving this HTML may not preserve browser storage.':'Browser storage is unavailable. Your edits are only in memory: export JSON before closing this page.';
 updateProgress();
}
function updateProgress(){const approved=known.filter(id=>entry(id).status==='approved').length,reviewed=known.filter(id=>entry(id).status!=='pending').length;$('progress').textContent=`${reviewed}/${known.length} reviewed · ${approved} approved`;}
function decisionHTML(id){const value=entry(id);return `<div class="decision-box"><div class="decision-row"><label for="decision-${id}">Your decision</label><select id="decision-${id}" data-decision-id="${id}"><option value="pending">Not reviewed</option><option value="approved">Approve recommendation</option><option value="changes">Request changes</option><option value="rejected">Reject recommendation</option></select><span class="decision-status" id="decision-status-${id}">${esc(value.updated?'Last edited '+new Date(value.updated).toLocaleString():'No decision recorded')}</span></div><label class="comment-label" for="comment-${id}">Comment / conditions of approval</label><textarea id="comment-${id}" data-comment-id="${id}" placeholder="What should change, or what must stay?">${esc(value.comment)}</textarea></div>`;}
const paths={check:'<path d="m5 12 4 4 10-10"/>',close:'<path d="m6 6 12 12M18 6 6 18"/>',delete:'<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v6M14 11v6"/>',undo:'<path d="m9 5-5 5 5 5M4 10h10a5 5 0 0 1 0 10h-3"/>'};
function command(label,affirm,v){const icon=affirm?(v.icon||(v.tone==='danger'?'delete':'check')):'close';return `<span role="img" aria-label="${esc(label)}" class="mock-command ${affirm?'affirm '+(v.tone||'')+(v.disabled?' disabled':''):''}"><span class="circle" aria-hidden="true"><svg viewBox="0 0 24 24">${paths[icon]}</svg></span></span>`;}
function mock(v){
 const description=[v.detail,v.metadata].filter(Boolean).join(' ');
 const hint=v.hint||(v.reject==='Reject'?'Enter confirm   •   Esc reject':'Enter confirm   •   Esc cancel');
 return `<div class="mock" role="group" aria-label="${esc(v.title)}" aria-description="${esc(description)}"><div class="mock-header"><span class="question-tile" aria-hidden="true"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 4 2c-1 .6-1.5 1-1.5 2M12 16v.2"/></svg></span><h3 class="mock-title">${esc(v.title)}</h3>${v.passive?'':`<div class="mock-actions">${command(v.reject||'Cancel',false,v)}${command(v.accept||'Confirm',true,v)}</div>`}</div>${v.code?`<div class="mock-code">${esc(v.code)}</div>`:''}${v.id==='bluetooth-display-passkey'?'<p class="mock-progress">3 / 6 digits</p>':''}${v.field?`<div class="mock-field"><span>${esc(v.field)}</span><div class="fake-input">${esc(v.placeholder)}</div></div>`:''}${v.passive?'':`<p class="mock-hint">${esc(hint)}</p>`}</div>`;
}
const currentVariants={};
function visualHTML(item,v){
 const keep=item.recommendation==='keep';
 return `<div class="visual"><div class="visual-title">Current · actual Qt screenshot</div><div class="stage"><button class="image-button" data-enlarge="${item.id}" data-image="current" aria-label="Enlarge current ${esc(item.title)} screenshot"><img class="current-image" src="${v.current}" alt="Current ${esc(v.label)} screen in ${esc(item.panel)}" loading="lazy"></button></div><button class="context" data-enlarge="${item.id}" data-image="context">Open full panel context ↗</button></div><div class="visual"><div class="visual-title">${keep?'Recommendation · retain current':'Replacement · HTML design mockup'}</div><div class="stage">${keep?`<img class="current-image" src="${v.current}" alt="Keep the current ${esc(v.label)} screen" loading="lazy">`:mock(v)}</div><div class="mock-caption">${keep?'No replacement necessary. Approving this item means keep its current presentation.':'Target layout: one question · Cancel then Approve at the right · no explanatory paragraph.'}</div></div>`;
}
function render(){
 $('reference-image').src=data.reference;
 $('direction-decision').innerHTML=decisionHTML('direction');
 $('cards').innerHTML=data.items.map((item,index)=>{currentVariants[item.id]=0;return `<article class="review-card" id="${item.id}" data-decision="${entry(item.id).status}"><div class="card-top"><div><p class="eyebrow">${esc(item.panel)} / ${esc(item.category)}</p><h2><span class="number">${String(index+1).padStart(2,'0')} / </span>${esc(item.title)}</h2></div><span class="tag ${item.recommendation}">${item.recommendation==='keep'?'Keep current':'Propose change'}</span></div><div class="source">${esc(item.source)}</div><p class="reason">${esc(item.reason)}</p>${item.variants.length>1?`<div class="variants" aria-label="Captured variants">${item.variants.map((v,n)=>`<button data-variant-item="${item.id}" data-variant-index="${n}" aria-pressed="${n===0}">${esc(v.label)}</button>`).join('')}</div>`:''}<div class="comparison" id="comparison-${item.id}">${visualHTML(item,item.variants[0])}</div><p class="safety"><strong>Preserve:</strong> ${esc(item.guards)}</p>${item.variants.length>1?'<p class="muted" style="font-size:12px">Approval applies to all variants above; identify any exception in your comment.</p>':''}${decisionHTML(item.id)}</article>`;}).join('');
 let lastPanel='';$('nav').innerHTML='<a href="#direction">00 · Shared direction</a>'+data.items.map((i,n)=>{const label=i.panel!==lastPanel?`<b>${esc(i.panel)}</b>`:'';lastPanel=i.panel;return `${label}<a href="#${i.id}">${String(n+1).padStart(2,'0')} · ${esc(i.title)}</a>`;}).join('')+'<b>Review notes</b><a href="#coverage">Coverage & exclusions</a>';
 for(const id of known){$('decision-'+id).value=entry(id).status;$(id).dataset.decision=entry(id).status;}
 $('global-comment').value=feedback.overall;
 $('provenance').textContent=`Captured from working tree at HEAD ${data.head} · Built ${new Date(data.generated).toLocaleString()}. 23 capture cases passed (25 Qt passes including lifecycle; zero failures/skips). Reproduce: mkdir -p target/confirmation-review; tests/run-qmlquality-tests.sh -input tests/manual/tst_confirmation_review.qml; python3 tests/manual/build-confirmation-review.py. Images embedded; no network dependencies or telemetry. Proposals are not implementation screenshots.`;
 updateProgress();filterCards();
}
function filterCards(){let shown=0;const term=$('search').value.toLowerCase(),filter=$('filter').value;for(const item of data.items){const text=[item.panel,item.title,item.reason,item.source,...item.variants.map(v=>v.label+' '+v.title)].join(' ').toLowerCase();const matches=filter==='all'||filter===entry(item.id).status||(filter==='keep'&&item.recommendation==='keep')||(filter==='confirmation'&&item.category==='confirmation');const visible=matches&&text.includes(term);$(item.id).hidden=!visible;if(visible)shown++;}$('no-matches').hidden=shown!==0;}
function record(id,patch){feedback.decisions[id]={...entry(id),...patch,updated:new Date().toISOString()};$(id).dataset.decision=entry(id).status;$('decision-status-'+id).textContent='Last edited '+new Date(entry(id).updated).toLocaleString();persist();}
document.addEventListener('input',e=>{if(e.target.dataset.commentId)record(e.target.dataset.commentId,{comment:e.target.value});if(e.target.id==='global-comment'){feedback.overall=e.target.value;persist();}});
document.addEventListener('change',e=>{if(e.target.dataset.decisionId){record(e.target.dataset.decisionId,{status:e.target.value});filterCards();}});
function openImage(src,title){$('viewer-image').src=src;$('viewer-image').alt=title;$('viewer-title').textContent=title;$('viewer').showModal();}
document.addEventListener('click',e=>{const tab=e.target.closest('[data-variant-item]');if(tab){const item=data.items.find(i=>i.id===tab.dataset.variantItem),n=Number(tab.dataset.variantIndex);currentVariants[item.id]=n;$('comparison-'+item.id).innerHTML=visualHTML(item,item.variants[n]);for(const b of $(item.id).querySelectorAll('[data-variant-item]'))b.setAttribute('aria-pressed',String(Number(b.dataset.variantIndex)===n));}const enlarge=e.target.closest('[data-enlarge]');if(enlarge){const item=data.items.find(i=>i.id===enlarge.dataset.enlarge),v=item.variants[currentVariants[item.id]];openImage(v[enlarge.dataset.image],`${item.panel} · ${v.label} · current Qt capture${enlarge.dataset.image==='context'?' · full panel':''}`);}});
$('reference-open').onclick=()=>openImage(data.reference,'Your target · one question, Cancel then Approve at the right');
$('viewer-close').onclick=()=>$('viewer').close();
$('viewer').addEventListener('click',e=>{if(e.target===$('viewer'))$('viewer').close();});
$('search').oninput=filterCards;$('filter').onchange=filterCards;
$('export').onclick=()=>{const exported={...feedback,exportedAt:new Date().toISOString(),sourceHead:data.head,items:data.items.map(i=>({id:i.id,panel:i.panel,title:i.title,recommendation:i.recommendation,variants:i.variants.map(v=>v.id)}))};const blob=new Blob([JSON.stringify(exported,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='shelllist-confirmation-decisions.json';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);announce('Decisions exported. Send the JSON back to share your review.');};
$('import').onclick=()=>$('import-file').click();
$('import-file').onchange=async e=>{const file=e.target.files[0];if(!file)return;try{if(file.size>2*1024*1024)throw Error('Feedback file is too large. Choose an exported decisions JSON.');const imported=normalize(JSON.parse(await file.text()));if(!confirm('Replace the current browser decisions and comments with this imported review?'))return;feedback=imported;persist();render();announce('Imported decisions and comments.');}catch(error){announce(error.message);}finally{e.target.value='';}};
render();
if(!storageAvailable)$('save-note').textContent='Saved feedback could not be loaded or browser storage is unavailable. Export JSON before closing; importing a backup remains available.';
</script></body></html>'''

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(TEMPLATE.replace("__DATA__", json.dumps(metadata, ensure_ascii=False).replace("<", "\\u003c")))
print(f"{OUTPUT}\n{len(ITEMS)} inventory items, {sum(len(i['variants']) for i in ITEMS)} captured states, {OUTPUT.stat().st_size:,} bytes")
