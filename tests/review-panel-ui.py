#!/usr/bin/env python3
"""Advisory changed-line review, not a ban on domain geometry or a pixel test."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCOPES = ["launcher", "wifi", "bluetooth", "clipboard", "displays", "battery",
          "activity", "bar/SystemChooserContent.qml"]
NUMERIC_ROLE = re.compile(r"\b(?:font\.pixelSize|spacing|\w*Margin|padding|radius)\s*:.*\b\d+(?:\.\d+)?\b")
COMPOSITION = re.compile(r"\b(?:Ui\.)?(?:FormField|SettingRow|ToggleRow|DetailColumnCard|SectionHeading|PanelMessage|InlineStatus)\s*\{")


def review(diff):
    path, line = "", 0
    for text in diff.splitlines():
        if text.startswith("+++ b/"):
            path = text[6:]
        elif text.startswith("@@"):
            match = re.search(r"\+(\d+)", text)
            if match:
                line = int(match[1])
        elif text.startswith("+") and path.endswith(".qml"):
            source = text[1:]
            if NUMERIC_ROLE.search(source):
                yield path, line, "numeric role: justify exception or use Theme", source.strip()
            if COMPOSITION.search(source):
                yield path, line, "composition: preserve native editor/command identity", source.strip()
            line += 1
        elif not text.startswith(("-", "\\")):
            line += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="HEAD", help="review base through the current working tree")
    args = parser.parse_args()
    diff = subprocess.check_output(["git", "diff", "--no-ext-diff", "--unified=0", args.base, "--", *SCOPES], cwd=ROOT, text=True)
    findings = list(review(diff))
    for path, line, reason, source in findings:
        print(f"{path}:{line}: {reason}\n  {source}")
    added = subprocess.check_output(["git", "diff", "--name-only", "--diff-filter=A", args.base, "--", *SCOPES], cwd=ROOT, text=True)
    wrappers = [path for path in added.splitlines() if re.search(r"(?:Setting|Field|Toggle|Switch).*\.qml$", path)]
    for path in wrappers:
        print(f"{path}: new local setting wrapper: prefer shared Ui composition; document necessity")
    print(f"\n{len(findings)} changed-line prompts; {len(wrappers)} new-wrapper prompts.")
    print("Advisory only. Record owner/reason for accepted exceptions; inspect new untracked files separately.")
    print("This does not verify interaction, accessibility, contrast or rendered geometry.")


if __name__ == "__main__":
    main()
