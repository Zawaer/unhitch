#!/usr/bin/env python3
"""
Generates the README diagrams as SVG, one pair per figure (light and dark), so
the repo carries no hand-drawn binary assets and the figures can be corrected by
editing this file.

    python3 Tools/make_diagrams.py
"""
import pathlib

FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"

THEMES = {
    "light": dict(card="#ffffff", edge="#d0d7de", pill="#f6f8fa", text="#1f2328",
                  muted="#656d76", bad="#bc4c00", good="#1a7f37", dim="#8c959f"),
    "dark":  dict(card="#161b22", edge="#30363d", pill="#0d1117", text="#e6edf3",
                  muted="#8b949e", bad="#d29922", good="#3fb950", dim="#6e7681"),
}


def text(x, y, s, size=14, fill="text", weight="400", anchor="start", spacing=None, t=None):
    extra = f' letter-spacing="{spacing}"' if spacing else ""
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" '
            f'font-weight="{weight}" fill="{t[fill]}" text-anchor="{anchor}"{extra}>{s}</text>')


def box(x, y, w, h, t, fill="card", radius=12, stroke="edge"):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{t[fill]}" stroke="{t[stroke]}" stroke-width="1"/>')


def tick(x, y, t, ok=True):
    """A check or a cross, drawn as paths so no font has to supply the glyph."""
    colour = t["good"] if ok else t["bad"]
    if ok:
        d = f"M{x} {y+1} l3.5 3.5 l7 -8"
    else:
        d = f"M{x} {y-3.5} l9 9 M{x+9} {y-3.5} l-9 9"
    return f'<path d="{d}" stroke="{colour}" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'


# --------------------------------------------------------------------------- #
# Figure 1 - the two-slot problem
# --------------------------------------------------------------------------- #

def slots(t):
    W, H = 860, 316
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="Two Bluetooth slots: without Unhitch a sleeping MacBook holds one of them; with Unhitch it steps aside.">']

    panels = [
        (24, "WITHOUT UNHITCH", [("SLOT 1", "iPhone", None), ("SLOT 2", "MacBook", "asleep, in your bag")],
         "iPad", "no slot left", False),
        (460, "WITH UNHITCH", [("SLOT 1", "iPhone", None), ("SLOT 2", "iPad", None)],
         "MacBook", "stepped aside", True),
    ]

    for px, heading, rows, foot_device, foot_note, ok in panels:
        out.append(text(px + 2, 26, heading, size=11, fill="muted", weight="600", spacing="1.4", t=t))
        out.append(box(px, 42, 376, 188, t))
        out.append(text(px + 24, 76, "WH-1000XM4", size=15, weight="600", t=t))
        out.append(text(px + 24, 96, "two connection slots, like most headsets",
                        size=11.5, fill="muted", t=t))

        for i, (slot, device, note) in enumerate(rows):
            y = 112 + i * 58
            highlight = (i == 1)
            out.append(box(px + 24, y, 328, 46, t, fill="pill", radius=9))
            out.append(text(px + 40, y + 28, slot, size=10, fill="dim", weight="600", spacing="1.2", t=t))
            label_fill = ("bad" if not ok else "good") if highlight else "text"
            out.append(text(px + 104, y + 28, device, size=14,
                            weight="600" if highlight else "400", fill=label_fill, t=t))
            if note:
                out.append(text(px + 104 + 9 * len(device), y + 28, f"  {note}", size=11.5, fill="muted", t=t))

        out.append(tick(px + 2, 276, t, ok=ok))
        out.append(text(px + 24, 281, foot_device, size=14, weight="600", t=t))
        out.append(text(px + 24 + 9 * len(foot_device), 281, f"  {foot_note}", size=13, fill="muted", t=t))

    out.append('</svg>')
    return "\n".join(out)


# --------------------------------------------------------------------------- #
# Figure 2 - why not just switch the radio off
# --------------------------------------------------------------------------- #

def radio(t):
    W, H = 860, 288
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="Turning the Bluetooth radio off also kills Find My and your keyboard. Unhitch closes one link instead.">']

    panels = [
        (24, "THE USUAL SLEEP SCRIPT", "blueutil off", [
            ("Headphones let go", True),
            ("Keyboard and trackpad", False),
            ("Find My offline finding", False),
        ]),
        (460, "UNHITCH", "one link closed", [
            ("Headphones let go", True),
            ("Keyboard and trackpad", True),
            ("Find My offline finding", True),
        ]),
    ]

    for px, heading, subtitle, rows in panels:
        out.append(text(px + 2, 26, heading, size=11, fill="muted", weight="600", spacing="1.4", t=t))
        out.append(box(px, 42, 376, 212, t))
        out.append(text(px + 24, 76, subtitle, size=15, weight="600", t=t))

        for i, (label, ok) in enumerate(rows):
            y = 96 + i * 50
            out.append(box(px + 24, y, 328, 40, t, fill="pill", radius=9))
            out.append(tick(px + 42, y + 20, t, ok=ok))
            out.append(text(px + 68, y + 25, label, size=13.5, fill="text" if ok else "muted", t=t))

    out.append('</svg>')
    return "\n".join(out)


docs = pathlib.Path("docs")
docs.mkdir(exist_ok=True)
for name, figure in (("slots", slots), ("radio", radio)):
    for theme, palette in THEMES.items():
        (docs / f"{name}-{theme}.svg").write_text(figure(palette) + "\n")
        print(f"wrote docs/{name}-{theme}.svg")
