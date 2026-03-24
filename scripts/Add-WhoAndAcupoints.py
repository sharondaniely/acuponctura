"""
Add WHO meridian chart images and AcuPoints.org links to all meridian markdown files.
- Adds WHO chart image after the existing Wellcome chart in the overview section
- Adds AcuPoints.org link to each point's External References line
"""

import re
import os

BASE = r"c:\#personal\acuponctura"
MERIDIANS_DIR = os.path.join(BASE, "year-1-foundations", "module-02-meridians")

ACUPOINTS_CODE_MAP = {
    "LU": "lu", "LI": "li", "ST": "st", "SP": "sp",
    "HT": "ht", "SI": "si", "BL": "bl", "KI": "ki",
    "PC": "pc", "TE": "te", "GB": "gb", "LR": "lr",
    "DU": "gv", "REN": "cv",
}

FILE_CONFIG = {
    "02-lung-channel.md":        {"channel": "LU", "who_img": "LU-lung-meridian-who.png"},
    "03-large-intestine.md":     {"channel": "LI", "who_img": "LI-large-intestine-meridian-who.png"},
    "04-stomach-channel.md":     {"channel": "ST", "who_img": "ST-stomach-meridian-who.png"},
    "05-spleen-channel.md":      {"channel": "SP", "who_img": "SP-spleen-meridian-who.png"},
    "06-heart-channel.md":       {"channel": "HT", "who_img": "HT-heart-meridian-who.png"},
    "07-small-intestine.md":     {"channel": "SI", "who_img": "SI-small-intestine-meridian-who.png"},
    "09-kidney-channel.md":      {"channel": "KI", "who_img": "KI-kidney-meridian-who.png"},
    "10-pericardium.md":         {"channel": "PC", "who_img": "PC-pericardium-meridian-who.png"},
    "11-triple-energizer.md":    {"channel": "TE", "who_img": "TE-triple-energizer-meridian-who.png"},
    "12-gallbladder.md":         {"channel": "GB", "who_img": "GB-gallbladder-meridian-who.png"},
    "13-liver-channel.md":       {"channel": "LR", "who_img": "LR-liver-meridian-who.png"},
    "14-extraordinary-vessels.md": {"channel": "DU/REN",
                                    "who_img_du": "GV-governor-vessel-who.png",
                                    "who_img_cv": "CV-conception-vessel-who.png"},
}


def make_acupoints_url(point_id):
    match = re.match(r"([A-Z]+)(\d+)", point_id)
    if not match:
        return None
    channel, num = match.group(1), match.group(2)
    code = ACUPOINTS_CODE_MAP.get(channel)
    if not code:
        return None
    return f"https://www.acupoints.org/{code}{num}-acupuncture-point/"


def add_acupoints_link(line, point_id):
    url = make_acupoints_url(point_id)
    if not url:
        return line
    acupoints_link = f"[AcuPoints]({url})"
    if "AcuPoints" in line:
        return line
    line = line.replace(
        "> **External References:**",
        f"> **External References:** {acupoints_link} |"
    )
    return line


def find_point_id_near_line(lines, line_idx):
    """Look backwards from a line to find the point ID from headers or image refs."""
    for i in range(line_idx, max(line_idx - 15, -1), -1):
        header_match = re.match(r"^###\s+([A-Z]{2,3}\d+)", lines[i])
        if header_match:
            return header_match.group(1)
        img_match = re.search(r"!\[([A-Z]{2,3}\d+)\]", lines[i])
        if img_match:
            return img_match.group(1)
    return None


def process_file(filepath, config):
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    content = "".join(lines)
    who_already_present = "WHO Standard Acupuncture Point Locations" in content

    modified = False
    new_lines = []
    who_chart_added = who_already_present
    i = 0

    while i < len(lines):
        line = lines[i]

        if "**External References:**" in line and "AcuPoints" not in line:
            point_id = find_point_id_near_line([l.rstrip() for l in lines], i)
            if point_id:
                line = add_acupoints_link(line, point_id)
                modified = True

        if not who_chart_added and "channel" in config:
            is_extraordinary = config["channel"] == "DU/REN"

            if is_extraordinary:
                if "DU Channel Chart" in line and "wellcome" in line.lower():
                    new_lines.append(line)
                    i += 1
                    who_block = (
                        "\n"
                        "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                        f"> ![WHO Governor Vessel Chart](../../images/references/who/{config['who_img_du']})\n"
                    )
                    new_lines.append(who_block)
                    modified = True
                    continue
                elif "REN Channel Chart" in line and "wellcome" in line.lower():
                    new_lines.append(line)
                    i += 1
                    who_block = (
                        "\n"
                        "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                        f"> ![WHO Conception Vessel Chart](../../images/references/who/{config['who_img_cv']})\n"
                    )
                    new_lines.append(who_block)
                    modified = True
                    continue
            else:
                channel = config["channel"]
                if "Channel Chart" in line and "wellcome" in line.lower() and channel.upper() in line.upper():
                    new_lines.append(line)
                    i += 1
                    who_block = (
                        "\n"
                        "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                        f"> ![WHO {channel} Meridian Chart](../../images/references/who/{config['who_img']})\n"
                    )
                    new_lines.append(who_block)
                    modified = True
                    who_chart_added = True
                    continue

        new_lines.append(line)
        i += 1

    if modified:
        with open(filepath, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

    return modified


def main():
    total_files = 0
    total_modified = 0

    for filename, config in FILE_CONFIG.items():
        filepath = os.path.join(MERIDIANS_DIR, filename)
        if not os.path.exists(filepath):
            print(f"SKIP (not found): {filename}")
            continue

        total_files += 1
        result = process_file(filepath, config)
        status = "UPDATED" if result else "no changes"
        print(f"{status}: {filename}")
        if result:
            total_modified += 1

    print(f"\nDone: {total_modified}/{total_files} files updated")


if __name__ == "__main__":
    main()
