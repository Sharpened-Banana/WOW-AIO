"""Wowhead guide data for the generators, read from tools/wowhead_dump.json.

The dump is produced in a browser by tools/wowhead_harvest.js (Wowhead's guide
pages are client-rendered and refuse non-browser clients, so no Python fetch
can replace that step); this module turns the raw per-spec records into the
same shapes the Icy Veins parsers produce, resolving item names and equip
slots through tools/wowhead_items.py where the harvested tables omit them.
"""
import json
import os
import re

from wowhead_items import lookup

DUMP = os.path.join(os.path.dirname(__file__), "wowhead_dump.json")

# Wowhead's own slot column labels -> Data/API.lua's 14-slot vocabulary.
# Anything not listed falls back to the item's tooltip slot.
SLOT_LABELS = {
    "head": "Head", "helm": "Head", "neck": "Neck", "shoulder": "Shoulder", "shoulders": "Shoulder",
    "back": "Back", "cape": "Back", "cloak": "Back", "chest": "Chest", "wrist": "Wrist", "bracers": "Wrist",
    "hands": "Hands", "gloves": "Hands", "waist": "Waist", "belt": "Waist", "legs": "Legs", "feet": "Feet",
    "boots": "Feet", "ring": "Ring", "trinket": "Trinket", "trinkets": "Trinket", "weapon": "Weapon",
    "weapons": "Weapon", "main hand": "Weapon", "main-hand": "Weapon", "mainhand": "Weapon",
    "1h weapon": "Weapon", "2h weapon": "Weapon", "off hand": "Off-hand", "off-hand": "Off-hand",
    "offhand": "Off-hand", "shield": "Off-hand",
}

TRINKET_SOURCES = {"raid": "Raid", "dungeon": "Dungeon", "delves": "Delves", "crafting": "Profession"}


def load():
    try:
        return {int(k): v for k, v in json.load(open(DUMP)).items()}
    except (OSError, ValueError):
        return {}


def _all_item_ids(dump):
    ids = set()
    for rec in dump.values():
        for table in rec.get("bis", []):
            for row in table["rows"]:
                ids.add(row[1])
        for tier in rec.get("tiers", []):
            for item_id, _ in tier["items"]:
                ids.add(item_id)
    return sorted(ids)


_items = None


def items(dump):
    """{ itemID: { name, slot, quality } } for every item the dump mentions (cached)."""
    global _items
    if _items is None:
        _items = lookup(_all_item_ids(dump))
    return _items


def _slot(label, info):
    key = re.sub(r"\s*\(.*\)$", "", label or "").strip().lower()   # "Trinket (Raid)" -> "trinket"
    key = re.sub(r"\s+\d$", "", key)                                 # "Ring 1" -> "ring"
    return SLOT_LABELS.get(key) or (info or {}).get("slot")


def bis_lists(dump, spec_id, spec_words):
    """[(title, rows)] for the spec, rows as {slot, itemID, name, from}. Only tables
    that look like a full BiS set (8+ rows) count; a guide's side tables
    ("Gearing Strategy", "Bonus Rolling") are skipped. When a guide carries
    more than one full set (one per hero tree), the title keeps the words
    that distinguish them."""
    rec = dump.get(spec_id)
    if not rec:
        return []
    info = items(dump)
    tables = [t for t in rec.get("bis", []) if len(t["rows"]) >= 8]
    out = []
    for table in tables:
        rows = []
        for label, item_id, _, source in table["rows"]:
            meta = info.get(item_id) or {}
            slot = _slot(label, meta)
            name = meta.get("name") or ""
            if not slot or not name:
                continue
            rows.append({"slot": slot, "itemID": item_id, "name": name, "from": source})
        if not rows:
            continue
        title = "Wowhead"
        if len(tables) > 1:
            words = re.sub(r"^.*?\bfor\b", "", table["title"], flags=re.I)
            for w in spec_words:
                words = re.sub(r"\b%s\b" % re.escape(w), "", words, flags=re.I)
            words = re.sub(r"\s+", " ", words).strip(" -")
            if words:
                title = "Wowhead (%s)" % words
        if any(t == title for t, _ in out):
            continue
        out.append((title, rows))
    return out


def trinket_tiers(dump, spec_id):
    """[{tier, items: [{itemID, name, source}]}] in the site's order, or []."""
    rec = dump.get(spec_id)
    if not rec:
        return []
    info = items(dump)
    tiers = []
    for tier in rec.get("tiers", []):
        rows, seen = [], set()
        for item_id, source in tier["items"]:
            if item_id in seen:
                continue
            seen.add(item_id)
            name = (info.get(item_id) or {}).get("name") or ""
            if not name:
                continue
            rows.append({"itemID": item_id, "name": name,
                         "source": TRINKET_SOURCES.get(source.split(",")[0], "")})
        if rows:
            tiers.append({"tier": tier["tier"], "items": rows})
    return tiers


def builds(dump, spec_id):
    """[{label, string}] with the hero-tree group folded into the label."""
    rec = dump.get(spec_id)
    if not rec:
        return []
    out, labels = [], {}
    for group, label, code in rec.get("builds", []):
        text = ("%s: %s" % (group, label)) if group else label
        n = labels.get(text, 0) + 1
        labels[text] = n
        if n > 1:
            text = "%s (%d)" % (text, n)
        out.append({"label": text, "string": code})
    return out


def updated(dump, spec_id, key="updated"):
    return (dump.get(spec_id) or {}).get(key)
