#!/usr/bin/env python3
"""Regenerates SpecSage/Data/BiS.lua from Icy Veins' per-spec Best in Slot tables.

Each Icy Veins gear guide carries a "Best in Slot" block with one tab per
context (Overall, then Mythic+ and/or Raid where the guide splits them);
every entry is a .bis_item div with the item's wowhead ID, name, slot and
drop source. This turns that into one RegisterBiS(specID, ...) call per
spec: a list per tab, one row per slot, every row a concrete itemID the
Codex renders as a clickable item link. Wowhead's guide pages are rendered
client-side and refuse plain HTTP clients, so only Icy Veins is read.

Bonus IDs matter as much as the item ID. Icy Veins links every BiS entry as
"item=<id>&bonus=<a>:<b>...", and those bonus IDs are what put the item on
its current-season upgrade track - drop them and the client resolves the
bare item ID to the item's *base* form, which for a current dungeon neck is
a level-48 rare rather than the item level 334 epic the guide means. So the
bonus list rides along into Data/BiS.lua and the Codex builds a full item
string from it. Icy Veins also appends "&original-item=<id>" to catalysed
pieces (the token's pre-catalyst source); that is not part of the bonus
list and is dropped.

Wowhead's own guide markup carries bare "[item=<id>]" with no bonus list -
the site applies a default upgrade context when it renders. Rather than
invent one, Wowhead rows reuse the bonus list Icy Veins publishes for the
*same item ID* where one exists, and stay bare where none does.

Run from the repo root:  python3 tools/fetch_bis.py
"""
import datetime
import html
import json
import re
import sys
import time

sys.path.insert(0, "tools")
from specs import SPECS, fetch, lua_str, icy_veins_updated  # noqa: E402
import wowhead  # noqa: E402

# Icy Veins slot labels -> the Data/API.lua 14-slot vocabulary.
SLOT_MAP = {
    "head": "Head", "helm": "Head", "neck": "Neck", "shoulder": "Shoulder", "shoulders": "Shoulder",
    "back": "Back", "cloak": "Back", "chest": "Chest", "wrist": "Wrist", "wrists": "Wrist",
    "bracers": "Wrist", "hands": "Hands", "gloves": "Hands", "waist": "Waist", "belt": "Waist",
    "legs": "Legs", "feet": "Feet", "boots": "Feet", "ring": "Ring", "ring 1": "Ring", "ring 2": "Ring",
    "finger": "Ring", "trinket": "Trinket", "trinket 1": "Trinket", "trinket 2": "Trinket",
    "main hand": "Weapon", "main-hand": "Weapon", "weapon": "Weapon", "two-hand": "Weapon",
    "two hand": "Weapon", "2h weapon": "Weapon", "ranged": "Weapon", "off hand": "Off-hand",
    "off-hand": "Off-hand", "offhand": "Off-hand", "shield": "Off-hand",
}


def strip_tags(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def parse_bonus(item_html):
    """The item's bonus-ID list as "a:b:c", or "" when the link carries none.

    Icy Veins writes the link as data-wowhead="item=<id>&amp;bonus=<a>:<b>"
    and appends "&amp;original-item=<id>" on catalysed pieces, so the value
    is unescaped and cut at the next parameter before it is read."""
    m = re.search(r'data-wowhead="([^"]+)"', item_html)
    if not m:
        return ""
    bm = re.search(r"bonus=([\d:]*)", html.unescape(m.group(1)))
    if not bm:
        return ""
    # Icy Veins writes a leading empty element on the returning older-expansion
    # dungeon pieces ("bonus=:12854" - no upgrade-track bonus, only a rank).
    # Wowhead tolerates that; a game client item string does not, so the list
    # is normalised to bare numbers here.
    return ":".join(part for part in bm.group(1).split(":") if part)


def parse_bis(body):
    """Returns [ { title, rows: [ {slot, itemID, name, from} ] } ] or None."""
    i = body.find('class="image_block best_in_slot"')
    if i < 0:
        return None
    block = body[i:]
    # The block runs to the first <h2> after its last .bis_item - the FAQ
    # dropdowns inside the block's own description carry heading markup of
    # their own, so cutting at the first heading cut the items off entirely.
    last_item = max((m.start() for m in re.finditer(r'class="bis_item', block)), default=-1)
    if last_item < 0:
        return None
    end = block.find("<h2 ", last_item)
    block = block[:end] if end > 0 else block

    titles = dict(re.findall(r'id="(bis_\d+_\d+)_button">([^<]+)<', block))
    tabs = []
    for m in re.finditer(r'<div class="image_block_content" id="(bis_\d+_\d+)">', block):
        tab_id = m.group(1)
        start = m.end()
        nxt = re.search(r'<div class="image_block_content" id="bis_', block[start:])
        seg = block[start:start + nxt.start()] if nxt else block[start:]
        rows = []
        for item in re.split(r'<div class="bis_item[ "]', seg)[1:]:
            im = re.search(r'data-wowhead="item=(\d+)[^"]*"[^>]*>\s*<img[^>]*>\s*<span[^>]*>([^<]+)<', item)
            if not im:
                im = re.search(r'data-wowhead="item=(\d+)[^"]*"[^>]*>([^<]+)<', item)
            if not im:
                continue
            bonus = parse_bonus(item)
            sm = re.search(r'class="bis_item_slot">([^<]+)<', item)
            slot_raw = strip_tags(sm.group(1)).lower() if sm else ""
            slot = SLOT_MAP.get(slot_raw)
            if not slot:
                # "Ring 1" / "Trinket 2" / "Main Hand" variants
                base = re.sub(r"\s*\d$", "", slot_raw)
                slot = SLOT_MAP.get(base)
            if not slot:
                print("  unmapped slot %r" % slot_raw, file=sys.stderr)
                continue
            dm = re.search(r'class="bis_item_drop">(.*?)</span>', item, re.S)
            rows.append({
                "slot": slot, "itemID": int(im.group(1)),
                "name": html.unescape(im.group(2)).strip(),
                "from": strip_tags(dm.group(1)) if dm else "",
                "bonus": bonus,
            })
        title = titles.get(tab_id, tab_id)
        # Some guides repeat the whole block (Discipline's page carries it
        # twice); the first list under a given title wins.
        if rows and not any(t["title"] == title for t in tabs):
            tabs.append({"title": title, "rows": rows})
    return tabs or None


def lua_row(r):
    parts = ["slot = %s" % lua_str(r["slot"]), "itemID = %d" % r["itemID"],
             "name = %s" % lua_str(r["name"]), "from = %s" % lua_str(r["from"])]
    if r.get("bonus"):
        parts.append("bonus = %s" % lua_str(r["bonus"]))
    return "      { %s }," % ", ".join(parts)


def main():
    out = [
        "-- Data/BiS.lua",
        "-- GENERATED by tools/fetch_bis.py - do not hand-edit; re-run the script.",
        "--",
        "-- Per-spec Best in Slot lists from Icy Veins' gear guides (one list per",
        "-- context: Overall, Mythic+, Raid) and Wowhead's (one per hero tree where the",
        "-- guide splits them; see tools/wowhead_harvest.js), one row per slot, every",
        "-- row a concrete itemID the Codex shows as a clickable item link. This is",
        "-- each site's editorial BiS at the time the script ran - it goes stale every",
        "-- patch, and the Codex says so - not a claim of the single best item for",
        "-- your character. See DESIGN.md's \"Linked BiS lists\".",
        "--",
        "-- A row's `bonus` is the item's bonus-ID list, \"a:b:c\", as Icy Veins links",
        "-- it. It is what puts the item on its current-season upgrade track: without",
        "-- it the client resolves the bare itemID to the item's base form, which for",
        "-- a current dungeon piece can be a level-48 rare rather than the item level",
        "-- 334 epic the guide means. Rows Wowhead lists carry the bonus list Icy",
        "-- Veins states for the same item, since Wowhead's own markup has none.",
        "-- Generated: %s UTC" % datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"),
        "",
        "local ADDON, ns = ...",
        "if not ns.GuideStore then return end",
        "",
    ]
    dump = wowhead.load()

    # Pass 1: read every Icy Veins guide. The bonus lists have to be complete
    # before any Wowhead row is written, since a Wowhead row borrows the bonus
    # list Icy Veins publishes for that item - possibly from another spec's
    # guide, which may not have been read yet in a single-pass loop.
    scraped = {}
    bonus_by_item = {}
    for classToken, specID, _, ivSlug, ivRole in SPECS:
        url = "https://www.icy-veins.com/wow/%s-pve-%s-gear-best-in-slot" % (ivSlug, ivRole)
        tabs, updated = None, None
        try:
            body = fetch(url)
            tabs, updated = parse_bis(body), icy_veins_updated(body)
        except Exception as exc:
            print("  %s: %s" % (url, exc), file=sys.stderr)
        time.sleep(0.5)
        scraped[specID] = (tabs, updated)
        for tab in tabs or []:
            for r in tab["rows"]:
                if r.get("bonus"):
                    bonus_by_item.setdefault(r["itemID"], r["bonus"])

    # Pass 2: write the file.
    ok_count, borrowed, bare = 0, 0, 0
    for classToken, specID, _, ivSlug, _ in SPECS:
        tabs, updated = scraped[specID]
        spec_words = ivSlug.split("-")
        wh_lists = wowhead.bis_lists(dump, specID, spec_words)
        out.append("-- %s %d (%s)" % (classToken, specID, ivSlug))
        if not tabs and not wh_lists:
            print("%-12s %5d %-24s NO BIS TABLE" % (classToken, specID, ivSlug))
            out.append("")
            continue
        sources = []
        if tabs:
            sources.append("Icy Veins %s gear guide, updated %s" % (ivSlug.replace("-", " ").title(), updated or "?"))
        if wh_lists:
            sources.append("Wowhead %s gear guide, updated %s" % (ivSlug.replace("-", " ").title(),
                                                                 wowhead.updated(dump, specID) or "?"))
        out.append("ns.GuideStore:RegisterBiS(%d, {" % specID)
        out.append("  source = %s," % lua_str("; ".join(sources)))
        out.append('  patch = "12.1",')
        out.append("  lists = {")
        titles = []
        for tab in tabs or []:
            title = "Icy Veins " + tab["title"]
            titles.append("%s:%d" % (title, len(tab["rows"])))
            out.append("    { title = %s, list = {" % lua_str(title))
            for r in tab["rows"]:
                out.append(lua_row(r))
            out.append("    }},")
        for title, rows in wh_lists:
            titles.append("%s:%d" % (title, len(rows)))
            out.append("    { title = %s, list = {" % lua_str(title))
            for r in rows:
                if not r.get("bonus"):
                    r["bonus"] = bonus_by_item.get(r["itemID"], "")
                    if r["bonus"]:
                        borrowed += 1
                    else:
                        bare += 1
                out.append(lua_row(r))
            out.append("    }},")
        out.append("  },")
        out.append("})")
        out.append("")
        ok_count += 1
        print("%-12s %5d %-24s %s" % (classToken, specID, ivSlug, ", ".join(titles)))
    path = "SpecSage/Data/BiS.lua"
    with open(path, "w") as f:
        f.write("\n".join(out))
    print("wrote %s: %d specs" % (path, ok_count))
    print("bonus lists: %d distinct items from Icy Veins; %d Wowhead rows borrowed one, %d left bare"
          % (len(bonus_by_item), borrowed, bare))

    # Shared with tools/fetch_trinkets.py, which has no bonus source of its
    # own: bloodmallet reports bare item IDs and Icy Veins' Trinket Rankings
    # table links bare item IDs too, so a trinket only gets a bonus list when
    # some spec's BiS guide happens to name the same item.
    with open("tools/item_bonus.json", "w") as f:
        json.dump({str(k): v for k, v in sorted(bonus_by_item.items())}, f, indent=0, sort_keys=True)
    print("wrote tools/item_bonus.json: %d items" % len(bonus_by_item))


if __name__ == "__main__":
    main()
