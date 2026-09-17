#!/usr/bin/env python3
"""Filter a wowdev listfile to UI assets, ordered with restoration targets first."""
import argparse
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("listfile", type=Path)
p.add_argument("output", type=Path)
a = p.parse_args()
extensions = {".blp", ".tga", ".lua", ".xml", ".toc", ".ttf", ".otf", ".fnt"}
priority = {"mainmenubar", "minimap", "targetingframe", "characterframe", "questframe",
            "questlogframe", "talentframe", "paperdollinfoframe", "containerframe",
            "buttons", "dialogframe", "castingbar", "tooltips", "itemtextframe",
            "friendsframe", "spellbook", "framexml", "bankframe", "moneyframe",
            "taxiframe", "gossipframe", "lootframe", "merchantframe", "stationery",
            "mailframe", "auctionframe", "trainerframe", "tradeframe", "helpframe",
            "raidframe", "lfgframe", "classicon", "comboframe", "petactionbar",
            "chatframe", "optionsframe", "readycheck", "raidgroupframe", "groupframe"}
candidates = {}
with a.listfile.open() as source:
    for line in source:
        raw_id, sep, name = line.rstrip("\r\n").partition(";")
        name = name.replace("\\", "/").lower()
        if not sep or not raw_id.isdigit() or not name.startswith("interface/"):
            continue
        path = Path(name)
        if path.suffix not in extensions or ".." in path.parts:
            continue
        # Login/character creation art cannot be restored by an in-game addon.
        if len(path.parts) > 1 and path.parts[1] == "glues":
            continue
        candidates[name] = int(raw_id)
def order(name):
    path = Path(name)
    if path.suffix in {".lua", ".xml", ".toc"}: return (0, name)
    if len(path.parts) > 1 and path.parts[1] in priority: return (1, name)
    if name.startswith("interface/worldmap/") and len(path.parts) == 3: return (2, name)
    if name.startswith("interface/icons/"): return (4, name)
    if name.startswith("interface/worldmap/"): return (5, name)
    return (3, name)
a.output.parent.mkdir(parents=True, exist_ok=True)
with a.output.open("w") as output:
    for name in sorted(candidates, key=order):
        output.write(f"{candidates[name]};{name}\n")
print(f"{len(candidates)} UI candidates written to {a.output}")
