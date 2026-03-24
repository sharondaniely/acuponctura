"""Re-apply WHO images and AcuPoints links on the remote's gitbook format."""
import sys, io, re, os
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

md_dir = r"c:\#personal\acuponctura\year-1-foundations\module-02-meridians"
who_dir = r"c:\#personal\acuponctura\images\points-who"

ACUPOINTS_MAP = {
    "LU":"lu","LI":"li","ST":"st","SP":"sp","HT":"ht","SI":"si",
    "BL":"bl","KI":"ki","PC":"pc","TE":"te","GB":"gb","LR":"lr",
    "DU":"gv","REN":"cv",
}

WHO_CHARTS = {
    "02-lung-channel.md": ("LU", "LU-lung-meridian-who.png"),
    "03-large-intestine.md": ("LI", "LI-large-intestine-meridian-who.png"),
    "04-stomach-channel.md": ("ST", "ST-stomach-meridian-who.png"),
    "05-spleen-channel.md": ("SP", "SP-spleen-meridian-who.png"),
    "06-heart-channel.md": ("HT", "HT-heart-meridian-who.png"),
    "07-small-intestine.md": ("SI", "SI-small-intestine-meridian-who.png"),
    "08-bladder-channel.md": ("BL", "BL-bladder-meridian-who.png"),
    "09-kidney-channel.md": ("KI", "KI-kidney-meridian-who.png"),
    "10-pericardium.md": ("PC", "PC-pericardium-meridian-who.png"),
    "11-triple-energizer.md": ("TE", "TE-triple-energizer-meridian-who.png"),
    "12-gallbladder.md": ("GB", "GB-gallbladder-meridian-who.png"),
    "13-liver-channel.md": ("LR", "LR-liver-meridian-who.png"),
}

POINT_IMG_RE = re.compile(r"^!\[([A-Z]{2,3}\d+)\]\(.*\.(png|jpg)\)$")

total_who = 0
total_links = 0
total_charts = 0

files = sorted(f for f in os.listdir(md_dir)
               if f.endswith(".md") and f[0].isdigit() and f != "01-meridian-system.md")

for fname in files:
    fpath = os.path.join(md_dir, fname)
    with open(fpath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    new_lines = []
    chart_added = False
    gv_chart_added = False
    cv_chart_added = False
    file_who = 0
    file_links = 0

    for i, line in enumerate(lines):
        stripped = line.rstrip("\n")

        if fname in WHO_CHARTS and not chart_added:
            ch, img = WHO_CHARTS[fname]
            if re.match(r"^#{2,4}\s+" + ch + r"1\b", stripped):
                new_lines.append(
                    "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                    ">\n"
                    "> ![WHO %s Meridian Chart](../../images/references/who/%s)\n\n" % (ch, img)
                )
                chart_added = True
                total_charts += 1

        if fname == "14-extraordinary-vessels.md":
            if not gv_chart_added and re.match(r"^#{2,4}\s+DU1\b", stripped):
                new_lines.append(
                    "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                    ">\n"
                    "> ![WHO GV Chart](../../images/references/who/GV-governor-vessel-who.png)\n\n"
                )
                gv_chart_added = True
                total_charts += 1
            if not cv_chart_added and re.match(r"^#{2,4}\s+REN1\b", stripped):
                new_lines.append(
                    "> **WHO Standard Acupuncture Point Locations** (WHO, CC BY-NC-SA 3.0 IGO):\n"
                    ">\n"
                    "> ![WHO CV Chart](../../images/references/who/CV-conception-vessel-who.png)\n\n"
                )
                cv_chart_added = True
                total_charts += 1

        new_lines.append(line)

        m = POINT_IMG_RE.match(stripped)
        if m:
            point_id = m.group(1)
            channel = re.match(r"[A-Z]+", point_id).group()
            num = re.search(r"\d+", point_id).group()

            lookahead = "".join(lines[i + 1 : i + 5])
            if "points-who" in lookahead:
                continue

            if os.path.isfile(os.path.join(who_dir, channel, "%s.png" % point_id)):
                new_lines.append("\n")
                new_lines.append(
                    "![%s - WHO](../../images/points-who/%s/%s.png)\n" % (point_id, channel, point_id)
                )
                file_who += 1

            code = ACUPOINTS_MAP.get(channel)
            if code:
                url = "https://www.acupoints.org/%s%s-acupuncture-point/" % (code, num)
                new_lines.append("\n")
                new_lines.append("> **External References:** [AcuPoints](%s)\n" % url)
                file_links += 1

    with open(fpath, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    total_who += file_who
    total_links += file_links
    ch_str = "Y" if (chart_added or gv_chart_added or cv_chart_added) else "N"
    print("%s: +%d WHO imgs, +%d links, chart=%s" % (fname, file_who, file_links, ch_str))

print("\nTOTAL: %d WHO images, %d AcuPoints links, %d charts" % (total_who, total_links, total_charts))
