"""
Add WHO point images to markdown files, alongside existing point images.
Transforms:
  ![LU1](../../images/points/LU/LU1.png)
Into:
  ![LU1](../../images/points/LU/LU1.png)
  ![LU1 - WHO](../../images/points-who/LU/LU1.png)
"""

import re
import os
import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

BASE = r"c:\#personal\acuponctura"
MERIDIANS_DIR = os.path.join(BASE, "year-1-foundations", "module-02-meridians")
WHO_DIR = os.path.join(BASE, "images", "points-who")

POINT_IMG_RE = re.compile(
    r"^(!\[([A-Z]{2,3}\d+)\]\(../../images/points/[A-Z]{2,3}/[A-Z]{2,3}\d+\.png\))$"
)


def who_image_exists(point_id):
    channel = re.match(r"[A-Z]+", point_id).group()
    path = os.path.join(WHO_DIR, channel, f"{point_id}.png")
    return os.path.isfile(path)


def process_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    new_lines = []
    added = 0

    for i, line in enumerate(lines):
        new_lines.append(line)
        stripped = line.rstrip("\n")
        m = POINT_IMG_RE.match(stripped)
        if m:
            point_id = m.group(2)
            channel = re.match(r"[A-Z]+", point_id).group()

            lookahead = "".join(lines[i + 1 : i + 4])
            if "points-who" in lookahead:
                continue

            if who_image_exists(point_id):
                who_ref = f"![{point_id} - WHO](../../images/points-who/{channel}/{point_id}.png)\n"
                new_lines.append("\n")
                new_lines.append(who_ref)
                added += 1

    if added > 0:
        with open(filepath, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

    return added


def main():
    total = 0
    for fname in sorted(os.listdir(MERIDIANS_DIR)):
        if not fname.endswith(".md") or fname == "README.md" or fname == "01-meridian-system.md":
            continue

        fpath = os.path.join(MERIDIANS_DIR, fname)
        try:
            added = process_file(fpath)
        except UnicodeDecodeError:
            for enc in ["utf-8-sig", "latin-1"]:
                try:
                    with open(fpath, "r", encoding=enc) as f:
                        content = f.read()
                    with open(fpath, "w", encoding="utf-8") as f:
                        f.write(content)
                    added = process_file(fpath)
                    break
                except Exception:
                    continue
            else:
                print(f"SKIP (encoding): {fname}")
                continue

        total += added
        print(f"{fname}: +{added} WHO images")

    print(f"\nTotal: {total} WHO point images added to markdown")


if __name__ == "__main__":
    main()
