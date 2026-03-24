"""
Extract individual acupuncture point illustrations from the WHO PDF.
Each page typically has 2 points (top/bottom halves).
Saves to images/points-who/CHANNEL/POINTID.png
"""

import fitz
import sys
import io
import re
import os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

PDF_PATH = r"C:\Users\sharonsp\Downloads\9789290613831-eng.pdf"
BASE = r"c:\#personal\acuponctura"
OUT_DIR = os.path.join(BASE, "images", "points-who")

CHANNEL_PREFIXES = ["LU", "LI", "ST", "SP", "HT", "SI", "BL", "KI", "PC", "TE", "GB", "LR", "GV", "CV"]

WHO_TO_PROJECT = {"GV": "DU", "CV": "REN"}

ZOOM = 3


def find_all_points(doc):
    """Scan PDF to find all point definitions and their page/position."""
    point_pages = {}

    for page_idx in range(33, 240):
        page = doc[page_idx]
        text = page.get_text()
        lines = text.split("\n")

        defined = []
        for line in lines:
            m = re.match(
                r"^((?:LU|LI|ST|SP|HT|SI|BL|KI|PC|TE|GB|LR|GV|CV)\d+):\s+\w+",
                line.strip(),
            )
            if m and m.group(1) not in defined:
                defined.append(m.group(1))

        for idx, pid in enumerate(defined):
            if pid not in point_pages:
                point_pages[pid] = (page_idx, "top" if idx == 0 else "bottom")

    return point_pages


def extract_point_image(doc, page_idx, position):
    """Render and crop a point illustration from a PDF page."""
    page = doc[page_idx]
    mat = fitz.Matrix(ZOOM, ZOOM)
    page_h = page.rect.height

    if position == "top":
        clip = fitz.Rect(0, 0, page.rect.width, page_h / 2)
    else:
        clip = fitz.Rect(0, page_h / 2, page.rect.width, page_h)

    pix = page.get_pixmap(matrix=mat, clip=clip)
    return pix


def main():
    doc = fitz.open(PDF_PATH)
    point_pages = find_all_points(doc)

    print(f"Found {len(point_pages)} points in PDF")
    print()

    saved = 0
    for pid in sorted(point_pages.keys(), key=lambda x: (x[:2], int(re.search(r"\d+", x).group()))):
        page_idx, position = point_pages[pid]
        channel = re.match(r"[A-Z]+", pid).group()

        project_channel = WHO_TO_PROJECT.get(channel, channel)
        project_pid = pid.replace(channel, project_channel) if channel in WHO_TO_PROJECT else pid

        ch_dir = os.path.join(OUT_DIR, project_channel)
        os.makedirs(ch_dir, exist_ok=True)

        out_path = os.path.join(ch_dir, f"{project_pid}.png")
        pix = extract_point_image(doc, page_idx, position)
        pix.save(out_path)
        saved += 1

    doc.close()

    print(f"Extracted {saved} point images")
    for ch in CHANNEL_PREFIXES:
        proj_ch = WHO_TO_PROJECT.get(ch, ch)
        ch_dir = os.path.join(OUT_DIR, proj_ch)
        if os.path.isdir(ch_dir):
            count = len([f for f in os.listdir(ch_dir) if f.endswith(".png")])
            print(f"  {proj_ch}: {count} images")


if __name__ == "__main__":
    main()
