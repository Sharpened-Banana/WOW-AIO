"""Item name / equip-slot lookup through Wowhead's public tooltip endpoint.

    https://nether.wowhead.com/tooltip/item/<id>?dataEnv=1&locale=0

returns { name, quality, icon, tooltip (HTML) }; the slot is the tooltip line
after "Binds when ..." ("Neck", "Trinket", "Two-Hand", ...). Results are
cached in tools/wowhead_items.json so re-runs only fetch new ids.
"""
import html
import json
import os
import re
import time

from specs import fetch

CACHE = os.path.join(os.path.dirname(__file__), "wowhead_items.json")

# Tooltip slot text -> Data/API.lua 14-slot vocabulary.
SLOT_MAP = {
    "Head": "Head", "Neck": "Neck", "Shoulder": "Shoulder", "Back": "Back", "Chest": "Chest",
    "Wrist": "Wrist", "Hands": "Hands", "Waist": "Waist", "Legs": "Legs", "Feet": "Feet",
    "Finger": "Ring", "Trinket": "Trinket", "Main Hand": "Weapon", "One-Hand": "Weapon",
    "Two-Hand": "Weapon", "Ranged": "Weapon", "Off Hand": "Off-hand", "Held In Off-hand": "Off-hand",
    "Shield": "Off-hand",
}


def _load():
    try:
        return json.load(open(CACHE))
    except (OSError, ValueError):
        return {}


def lookup(item_ids, delay=0.2):
    """Returns { itemID: { name, slot, quality } } for every id, fetching the unknown ones."""
    cache = _load()
    missing = [i for i in item_ids if str(i) not in cache]
    for n, item_id in enumerate(missing):
        try:
            d = json.loads(fetch("https://nether.wowhead.com/tooltip/item/%d?dataEnv=1&locale=0" % item_id))
            text = re.sub(r"<[^>]+>", "|", d.get("tooltip", ""))
            text = re.sub(r"\|+", "|", html.unescape(text))
            slot = None
            for token in text.split("|"):
                token = token.strip()
                if token in SLOT_MAP:
                    slot = SLOT_MAP[token]
                    break
            cache[str(item_id)] = {"name": d.get("name", ""), "slot": slot, "quality": int(d.get("quality", 0) or 0)}
        except Exception as exc:  # keep going; the caller decides what to do with a gap
            cache[str(item_id)] = {"name": "", "slot": None, "quality": 0, "error": str(exc)[:80]}
        time.sleep(delay)
        if (n + 1) % 50 == 0:
            json.dump(cache, open(CACHE, "w"), indent=0, sort_keys=True)
    json.dump(cache, open(CACHE, "w"), indent=0, sort_keys=True)
    return {int(k): v for k, v in cache.items() if int(k) in set(item_ids)}
