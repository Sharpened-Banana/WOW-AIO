#!/usr/bin/env python3
"""Regenerates every spec's `consumables` block in SpecSage/Data/Guides_*.lua.

Each spec's block is derived from three things the guide already states -
its role, its stat priority, and its class (which fixes the primary stat) -
against a catalogue of the current expansion's consumables, enchants and
gems. Every item in the catalogue was looked up on Wowhead (name, item ID,
tooltip effect) on the date in CATALOGUE_CHECKED; the tooltips are what the
stat mappings below are built from. Item names are rank-2 (crafted) or the
Flawless (gem) tier, the top quality a player would actually buy.

Run from the repo root:  python3 tools/gen_consumables.py
Then:                    lua tests/run.lua

Entry shape written into the guides:
    { slot = "Flask", items = { 241325, 241323 }, text = "..." }
`items` are the item IDs the Codex draws as hoverable chips under the line
(UI/Codex.lua RenderConsumables), in the order given; `text` is the prose.
"""

import re
import sys
from pathlib import Path

CATALOGUE_CHECKED = "2026-09-05"
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "SpecSage" / "Data"

# ---------------------------------------------------------------------------
# Catalogue: name -> item ID. Wowhead, CATALOGUE_CHECKED.
# ---------------------------------------------------------------------------
ITEMS = {
    # Flasks (Alchemy, +152 of one secondary for 1h, persists through death)
    "Flask of the Blood Knights": 241325,          # Haste
    "Flask of the Magisters": 241323,              # Mastery
    "Flask of the Shattered Sun": 241327,          # Critical Strike
    "Flask of Thalassian Resistance": 241321,      # Versatility
    # Combat potions
    "Potion of Recklessness": 241289,              # +1585 highest secondary, -213 lowest, 30s
    "Light's Potential": 241309,                   # +593 primary stat, 30s
    "Liquid Luster": 271887,                       # 12.1: Versatility ramp, 5 stacks over 30s
    "Light's Preservation": 241287,                # 93,662 absorb shield, 30s
    "Lightfused Mana Potion": 241301,              # 22,362 mana
    "Potion of Devoured Dreams": 241295,           # mana over 10s, defenceless while channelling
    "Concentrated Silvermoon Health Potion": 271884,  # 12.1: 421,200 health
    # Food
    "Loa's Gathering": 275265,                     # 12.1 feast: Stamina + highest secondary
    "Feast of Knowledge": 275266,                  # 12.1 feast: Stamina + highest secondary
    "Harandar Celebration": 255846,                # feast: 98 Stamina + 50 primary
    "Silvermoon Parade": 255845,                   # feast: 98 Stamina + 50 primary
    "Hearty Venom-Spiced Cutlets": 275259,         # 12.1: 65 highest secondary, persists through death
    "Hearty Puffer Plate": 275262,                 # 12.1: 65 highest secondary, persists through death
    "Hearty Null and Void Plate": 242754,          # Haste, persists through death
    "Hearty Sun-Seared Lumifin": 242755,           # Critical Strike, persists through death
    "Hearty Warped Wise Wings": 242757,            # Mastery, persists through death
    "Hearty Void-Kissed Fish Rolls": 242756,       # Versatility, persists through death
    # Weapon oils (Enchanting) and stones (Blacksmithing), 2h
    "Thalassian Phoenix Oil": 243734,              # +16 Critical Strike and Haste
    "Oil of Dawn": 243736,                         # healing procs a 1,879 absorb
    "Smuggler's Enchanted Edge": 243738,           # damage procs 1,253 Arcane
    "Refulgent Whetstone": 237371,                 # +15 Attack Power, bladed
    "Refulgent Weightstone": 237369,               # +15 Attack Power, blunt
    # Augment runes
    "Void-Touched Augment Rune": 259085,           # +25 primary, 1h, does not persist through death
    "Soulgorged Augment Rune": 246492,             # +6 primary, persists through death, BoP
    "Crystallized Augment Rune": 224572,           # +6 primary
    # Weapon enchants (proc, 15s)
    "Enchant Weapon - Acuity of the Ren'dorei": 244029,   # +67 primary stat
    "Enchant Weapon - Berserker's Rage": 243973,          # +124 Haste
    "Enchant Weapon - Arcane Mastery": 244031,            # +124 Mastery
    "Enchant Weapon - Jan'alai's Precision": 243971,      # +124 Critical Strike
    "Enchant Weapon - Worldsoul Tenacity": 244001,        # +124 Versatility
    "Enchant Weapon - Worldsoul Aegis": 243999,           # 14,039 barrier when damaged, erupts
    "Enchant Weapon - Worldsoul Cradle": 243997,          # healing procs a 12,525 barrier on the target
    # Ring enchants (greater tier, +29)
    "Enchant Ring - Silvermoon's Alacrity": 244015,       # Haste
    "Enchant Ring - Zul'jin's Mastery": 243959,           # Mastery
    "Enchant Ring - Nature's Fury": 243987,               # Critical Strike
    "Enchant Ring - Silvermoon's Tenacity": 244017,       # Versatility
    # Chest
    "Enchant Chest - Mark of the Worldsoul": 243977,      # +50 primary
    "Enchant Chest - Mark of Nalorakk": 243947,           # +40 Strength, +116 Stamina
    "Enchant Chest - Mark of the Rootwarden": 243975,     # +40 Agility, +15 Speed
    "Enchant Chest - Mark of the Magister": 244003,       # +40 Intellect, +5% mana
    # Legs
    "Sunfire Silk Spellthread": 240133,                   # +41 Intellect, +115 Stamina
    "Arcanoweave Spellthread": 240155,                    # +41 Intellect, +4% mana
    "Forest Hunter's Armor Kit": 244641,                  # +41 Agility/Strength, +115 Stamina
    "Blood Knight's Armor Kit": 244643,                   # +41 Agility/Strength, +27 armor
    # Helm / shoulders / boots
    "Enchant Helm - Blessing of Speed": 243979,           # +13 Speed
    "Enchant Helm - Rune of Avoidance": 244005,           # +22 Avoidance
    "Enchant Helm - Hex of Leeching": 243949,             # +33 Leech
    "Enchant Shoulders - Akil'zon's Swiftness": 243963,   # +65 Speed
    "Enchant Shoulders - Silvermoon's Mending": 244021,   # +166 Leech
    "Enchant Shoulders - Amirdrassil's Grace": 243991,    # +111 Avoidance
    "Enchant Boots - Farstrider's Hunt": 244009,          # +11 Speed, +232 Stamina
    "Enchant Boots - Shaladrassil's Roots": 243983,       # +28 Leech, +232 Stamina
    "Enchant Boots - Lynx's Dexterity": 243953,           # +19 Avoidance, +232 Stamina
    # Gems
    "Powerful Eversong Diamond": 240967,   # +23 primary, +0.15% crit effectiveness per unique gem colour
    "Stoic Eversong Diamond": 240971,      # +23 primary, +13 armor
    "Telluric Eversong Diamond": 240969,   # +23 primary, +1% mana per unique gem colour
    "Flawless Quick Peridot": 240888,      # +17 Haste
    "Flawless Deadly Garnet": 240904,      # +17 Critical Strike
    "Flawless Masterful Amethyst": 240896, # +17 Mastery
    "Flawless Versatile Lapis": 240912,    # +17 Versatility
    "Flawless Deadly Peridot": 240890,     # +16 Haste, +7 Crit
    "Flawless Masterful Peridot": 240892,  # +16 Haste, +7 Mastery
    "Flawless Versatile Peridot": 240894,  # +16 Haste, +7 Vers
    "Flawless Quick Garnet": 240906,       # +16 Crit, +7 Haste
    "Flawless Masterful Garnet": 240908,   # +16 Crit, +7 Mastery
    "Flawless Versatile Garnet": 240910,   # +16 Crit, +7 Vers
    "Flawless Quick Amethyst": 240900,     # +16 Mastery, +7 Haste
    "Flawless Deadly Amethyst": 240898,    # +16 Mastery, +7 Crit
    "Flawless Versatile Amethyst": 240902, # +16 Mastery, +7 Vers
    "Flawless Quick Lapis": 240916,        # +16 Vers, +7 Haste
    "Flawless Deadly Lapis": 240914,       # +16 Vers, +7 Crit
    "Flawless Masterful Lapis": 240918,    # +16 Vers, +7 Mastery
}

STAT_LABEL = {"haste": "Haste", "crit": "Critical Strike", "mastery": "Mastery", "versatility": "Versatility"}
FLASK = {"haste": "Flask of the Blood Knights", "mastery": "Flask of the Magisters",
         "crit": "Flask of the Shattered Sun", "versatility": "Flask of Thalassian Resistance"}
STAT_FOOD = {"haste": "Hearty Null and Void Plate", "crit": "Hearty Sun-Seared Lumifin",
             "mastery": "Hearty Warped Wise Wings", "versatility": "Hearty Void-Kissed Fish Rolls"}
WEAPON_ENCHANT = {"haste": "Enchant Weapon - Berserker's Rage", "mastery": "Enchant Weapon - Arcane Mastery",
                  "crit": "Enchant Weapon - Jan'alai's Precision", "versatility": "Enchant Weapon - Worldsoul Tenacity"}
RING_ENCHANT = {"haste": "Enchant Ring - Silvermoon's Alacrity", "mastery": "Enchant Ring - Zul'jin's Mastery",
                "crit": "Enchant Ring - Nature's Fury", "versatility": "Enchant Ring - Silvermoon's Tenacity"}
GEM_BASE = {"haste": "Peridot", "crit": "Garnet", "mastery": "Amethyst", "versatility": "Lapis"}
GEM_ADJ = {"haste": "Quick", "crit": "Deadly", "mastery": "Masterful", "versatility": "Versatile"}

# Which primary stat a class (or, where it splits, a spec) uses.
PRIMARY_BY_CLASS = {
    "WARRIOR": "STR", "PALADIN": "STR", "DEATHKNIGHT": "STR",
    "HUNTER": "AGI", "ROGUE": "AGI", "DEMONHUNTER": "AGI",
    "MAGE": "INT", "PRIEST": "INT", "WARLOCK": "INT", "EVOKER": "INT",
}
PRIMARY_BY_SPEC = {
    # Druid
    102: "INT", 103: "AGI", 104: "AGI", 105: "INT",
    # Monk
    268: "AGI", 269: "AGI", 270: "INT",
    # Shaman
    262: "INT", 263: "AGI", 264: "INT",
}


def secondaries(stats):
    return [s for s in stats if s in STAT_LABEL]


def lua_str(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'


def entry(slot, names, text):
    ids = ", ".join(str(ITEMS[n]) for n in names)
    return f'    {{ slot = {lua_str(slot)}, items = {{ {ids} }}, text = {lua_str(text)} }},'


def build(cls, spec_id, role, stats):
    primary = PRIMARY_BY_SPEC.get(spec_id) or PRIMARY_BY_CLASS[cls]
    sec = secondaries(stats)
    top, second = sec[0], sec[1]
    top_l, second_l = STAT_LABEL[top], STAT_LABEL[second]
    tank, healer = role == "TANK", role == "HEALER"
    physical = primary in ("STR", "AGI")
    lines = []

    # Flask
    flasks = [FLASK[top], FLASK[second]]
    text = (f"{FLASK[top]} for {top_l}, this spec's top secondary; {FLASK[second]} if your gear already "
            f"leans hard into {top_l} and {second_l} is the stat you're short on.")
    if tank and top != "versatility":
        flasks.append(FLASK["versatility"])
        text += " Flask of Thalassian Resistance (Versatility) is the survivability pick for progression."
    lines.append(entry("Flask", flasks, text))

    # Food
    foods = ["Loa's Gathering", "Feast of Knowledge", "Harandar Celebration", "Hearty Venom-Spiced Cutlets", STAT_FOOD[top]]
    text = ("Raid feasts: Loa's Gathering or Feast of Knowledge (Stamina plus your highest secondary, new in 12.1), "
            "or Harandar Celebration / Silvermoon Parade (Stamina plus 50 primary stat) - the two families sim within a "
            f"fraction of a percent of each other, so eat whichever is down. Solo and Mythic+: Hearty Venom-Spiced Cutlets or "
            f"Hearty Puffer Plate (highest secondary) or {STAT_FOOD[top]} ({top_l}); Hearty food persists through death.")
    lines.append(entry("Food", foods, text))

    # Potion
    if healer:
        pots = ["Lightfused Mana Potion", "Potion of Devoured Dreams", "Potion of Recklessness", "Concentrated Silvermoon Health Potion"]
        text = ("Lightfused Mana Potion is the safe mana return; Potion of Devoured Dreams gives more over 10s but leaves you "
                "defenceless while it channels, so only when nothing is targeting you. Potion of Recklessness (+1585 highest "
                "secondary for 30s) for a throughput window instead. Always carry Concentrated Silvermoon Health Potions.")
    elif tank:
        pots = ["Light's Preservation", "Potion of Recklessness", "Liquid Luster", "Concentrated Silvermoon Health Potion"]
        text = ("Light's Preservation (a 93k absorb for 30s) for the pull or phase that actually threatens you; Potion of "
                "Recklessness (+1585 highest secondary) when damage matters more, or Liquid Luster (12.1) for a Versatility "
                "ramp that covers both. Always carry Concentrated Silvermoon Health Potions - 421k, the 12.1 upgrade.")
    else:
        pots = ["Potion of Recklessness", "Light's Potential", "Liquid Luster", "Concentrated Silvermoon Health Potion"]
        text = (f"Potion of Recklessness (+1585 {top_l} for 30s, at the cost of 213 of your lowest secondary) is the burst "
                "potion; Light's Potential (+593 primary stat) if your lowest secondary is one you can't afford to lose. "
                "Liquid Luster (12.1) ramps Versatility over 30s and suits a pre-pot into a long opener. Always carry "
                "Concentrated Silvermoon Health Potions - 421k, the 12.1 upgrade.")
    lines.append(entry("Potion", pots, text))

    # Weapon oil / stone
    oils = ["Thalassian Phoenix Oil"]
    text = "Thalassian Phoenix Oil - the current tier's weapon oil (+16 Critical Strike and Haste for 2 hours, from Enchanting)"
    if healer:
        oils.append("Oil of Dawn")
        text += "; Oil of Dawn instead if you'd rather your heals proc a small absorb on their target"
    if physical:
        oils += ["Refulgent Whetstone", "Refulgent Weightstone"]
        text += ("; Refulgent Whetstone (bladed) or Refulgent Weightstone (blunt) gives +15 Attack Power instead, from "
                 "Blacksmithing - the two are close, so take whichever is cheaper")
    text += "."
    lines.append(entry("Weapon Oil", oils, text))

    # Weapon enchant
    wep = ["Enchant Weapon - Acuity of the Ren'dorei", WEAPON_ENCHANT[top]]
    text = (f"Acuity of the Ren'dorei procs +67 primary stat for 15s; {WEAPON_ENCHANT[top].split(' - ')[1]} procs +124 {top_l} "
            "instead. The primary-stat proc is the usual default; take the secondary one if your stat weights put "
            f"{top_l} well clear of the rest.")
    if tank:
        wep.append("Enchant Weapon - Worldsoul Aegis")
        text += " Worldsoul Aegis (a 14k barrier that erupts when it breaks) is the defensive alternative."
    if healer:
        wep.append("Enchant Weapon - Worldsoul Cradle")
        text += " Worldsoul Cradle (heals proc a 12.5k barrier on the target) is the healer-flavoured alternative."
    lines.append(entry("Weapon Enchant", wep, text))

    # Rings
    rings = [RING_ENCHANT[top], RING_ENCHANT[second]]
    text = (f"{RING_ENCHANT[top].split(' - ')[1]} (+29 {top_l}) on both rings; {RING_ENCHANT[second].split(' - ')[1]} "
            f"(+29 {second_l}) if you're topping up your second stat instead. Use the greater tier - the lesser one is +24.")
    lines.append(entry("Ring Enchants", rings, text))

    # Chest
    chest = ["Enchant Chest - Mark of the Worldsoul"]
    text = "Mark of the Worldsoul (+50 primary stat)"
    if tank and primary == "STR":
        chest.append("Enchant Chest - Mark of Nalorakk")
        text += "; Mark of Nalorakk (+40 Strength, +116 Stamina) when you want the health instead"
    elif primary == "AGI":
        chest.append("Enchant Chest - Mark of the Rootwarden")
        text += "; Mark of the Rootwarden (+40 Agility, +15 Speed) trades a little stat for movement"
    elif healer:
        chest.append("Enchant Chest - Mark of the Magister")
        text += "; Mark of the Magister (+40 Intellect, +5% mana) if mana is what runs out"
    text += "."
    lines.append(entry("Chest Enchant", chest, text))

    # Legs
    if primary == "INT":
        legs = ["Sunfire Silk Spellthread"]
        text = "Sunfire Silk Spellthread (+41 Intellect, +115 Stamina)"
        if healer:
            legs.append("Arcanoweave Spellthread")
            text += "; Arcanoweave Spellthread (+41 Intellect, +4% mana) if you'd rather have the mana than the health"
    else:
        legs = ["Forest Hunter's Armor Kit"]
        text = "Forest Hunter's Armor Kit (+41 primary stat, +115 Stamina)"
        if tank:
            legs.append("Blood Knight's Armor Kit")
            text += "; Blood Knight's Armor Kit (+41 primary stat, +27 armor) for the armour instead"
    text += "."
    lines.append(entry("Leg Enchant", legs, text))

    # Helm / shoulders / boots
    if tank:
        misc = ["Enchant Helm - Rune of Avoidance", "Enchant Shoulders - Silvermoon's Mending", "Enchant Boots - Shaladrassil's Roots",
                "Enchant Helm - Hex of Leeching", "Enchant Shoulders - Amirdrassil's Grace", "Enchant Boots - Lynx's Dexterity"]
        text = ("Helm: Rune of Avoidance (+22) or Hex of Leeching (+33). Shoulders: Silvermoon's Mending (+166 Leech) or "
                "Amirdrassil's Grace (+111 Avoidance). Boots: Shaladrassil's Roots (+28 Leech, +232 Stamina) or Lynx's "
                "Dexterity (+19 Avoidance, +232 Stamina). Leech is the stronger sustain pick for a tank; Avoidance for "
                "dungeons heavy on unavoidable AoE.")
    else:
        misc = ["Enchant Helm - Blessing of Speed", "Enchant Shoulders - Akil'zon's Swiftness", "Enchant Boots - Farstrider's Hunt",
                "Enchant Shoulders - Silvermoon's Mending", "Enchant Boots - Shaladrassil's Roots"]
        text = ("Helm: Blessing of Speed (+13). Shoulders: Akil'zon's Swiftness (+65 Speed) or Silvermoon's Mending "
                "(+166 Leech). Boots: Farstrider's Hunt (+11 Speed, +232 Stamina) or Shaladrassil's Roots (+28 Leech, "
                "+232 Stamina). Speed is the throughput-neutral default; swap to Leech for a progression fight you "
                "keep dying on.")
    lines.append(entry("Helm, Shoulders and Boots", misc, text))

    # Gems
    diamond = "Powerful Eversong Diamond"
    diamond_text = "Powerful Eversong Diamond (+23 primary stat and crit effectiveness per unique gem colour you socket)"
    if tank:
        diamond, diamond_text = "Stoic Eversong Diamond", "Stoic Eversong Diamond (+23 primary stat, +13 armor)"
    elif healer:
        diamond, diamond_text = "Telluric Eversong Diamond", "Telluric Eversong Diamond (+23 primary stat, +1% mana per unique gem colour)"
    single = f"Flawless {GEM_ADJ[top]} {GEM_BASE[top]}"
    hybrid = f"Flawless {GEM_ADJ[second]} {GEM_BASE[top]}"
    gems = [diamond, single, hybrid]
    text = (f"One {diamond_text} - it's unique-equipped. Then {single} (+17 {top_l}) in every other socket, or "
            f"{hybrid} (+16 {top_l}, +7 {second_l}) to spread a second colour if your diamond counts colours.")
    lines.append(entry("Gems", gems, text))

    # Augment rune
    runes = ["Void-Touched Augment Rune", "Soulgorged Augment Rune", "Crystallized Augment Rune"]
    text = ("Void-Touched Augment Rune (+25 primary stat for 1 hour; it does not persist through death) for progression "
            "pulls and high keys. Soulgorged Augment Rune (+6, persists through death) or Crystallized Augment Rune (+6) "
            "are the cheap fallbacks the rest of the time.")
    lines.append(entry("Augment Rune", runes, text))

    return "  consumables = {\n" + "\n".join(lines) + "\n  },"


SPEC_RE = re.compile(r'RegisterSpec\("([A-Z]+)", (\d+), \{')
BLOCK_RE = re.compile(r'\n  consumables = \{\n.*?\n  \},', re.S)


def process(path):
    src = path.read_text()
    out, pos, count = [], 0, 0
    specs = list(SPEC_RE.finditer(src))
    for i, m in enumerate(specs):
        end = specs[i + 1].start() if i + 1 < len(specs) else len(src)
        chunk = src[m.start():end]
        cls, spec_id = m.group(1), int(m.group(2))
        role = re.search(r'\n  role = "([A-Z]+)"', chunk).group(1)
        stats = re.findall(r'\{ stat = "(\w+)"', chunk.split("rotation = {")[0])
        block = build(cls, spec_id, role, stats)
        new_chunk, n = BLOCK_RE.subn("\n" + block, chunk, count=1)
        if n != 1:
            sys.exit(f"{path.name}: spec {spec_id} has no consumables block to replace")
        out.append(src[pos:m.start()])
        out.append(new_chunk)
        pos = end
        count += 1
    out.append(src[pos:])
    path.write_text("".join(out))
    return count


def main():
    total = 0
    for path in sorted(DATA.glob("Guides_*.lua")):
        total += process(path)
    print(f"rewrote consumables for {total} specs")
    # The Codex's Data/Consumables.lua item table, so chip fallbacks and the
    # prose scanner know every name the guides now use.
    lines = [f'    ["{n}"] = {i},' for n, i in sorted(ITEMS.items(), key=lambda kv: kv[0].lower())]
    table = "ns.ConsumableItems = {\n" + "\n".join(lines) + "\n}"
    cons = (DATA / "Consumables.lua")
    src = cons.read_text()
    new_src, n = re.subn(r"ns\.ConsumableItems = \{\n.*?\n\}", lambda _: table, src, count=1, flags=re.S)
    if n != 1:
        sys.exit("Data/Consumables.lua: could not find ns.ConsumableItems to rewrite")
    cons.write_text(new_src)
    print(f"wrote {len(ITEMS)} items to Data/Consumables.lua")


if __name__ == "__main__":
    main()
