#!/usr/bin/env python3
"""Regenerates SpecSage/Data/Trinkets.lua from bloodmallet.com's public sim charts.

bloodmallet (github.com/Bloodmallet/bloodmallet_web_frontend, GPL-3.0) runs
SimulationCraft trinket sims for every spec SimC has a current-tier profile
for and exposes the result as JSON:

    https://bloodmallet.com/chart/get/trinkets/<fight style>/<class>/<spec>

Each response carries, per trinket, the simulated DPS at every item level it
was run at, plus the trinket's itemID, source (Raid/Dungeon/Profession/PvP)
and whether it is an on-use ("active") trinket. This script turns that into
one RegisterTrinkets(...) call per spec: the top TOP_N trinkets for each of
the fight styles below, each scored as a percentage gain over the spec's
baseline (no trinket) and bucketed into an S/A/B/C tier by how close it sits
to the best trinket's gain.

Specs bloodmallet has no chart for get a RegisterTrinkets call with an
`unavailable` reason instead, so the Codex can say why rather than showing
nothing: SimC does not simulate healing at all, and it has not published a
current-tier profile for a few DPS/tank specs yet (see the UNAVAILABLE table).

Run from the repo root:  python3 tools/fetch_trinkets.py
"""

import datetime
import json
import sys
import time
import urllib.request

TOP_N = 15

# (classToken, specID, bloodmallet slug)
SPECS = [
    ("WARRIOR", 71, "warrior/arms"), ("WARRIOR", 72, "warrior/fury"), ("WARRIOR", 73, "warrior/protection"),
    ("PALADIN", 65, "paladin/holy"), ("PALADIN", 66, "paladin/protection"), ("PALADIN", 70, "paladin/retribution"),
    ("HUNTER", 253, "hunter/beast_mastery"), ("HUNTER", 254, "hunter/marksmanship"), ("HUNTER", 255, "hunter/survival"),
    ("ROGUE", 259, "rogue/assassination"), ("ROGUE", 260, "rogue/outlaw"), ("ROGUE", 261, "rogue/subtlety"),
    ("PRIEST", 256, "priest/discipline"), ("PRIEST", 257, "priest/holy"), ("PRIEST", 258, "priest/shadow"),
    ("DEATHKNIGHT", 250, "death_knight/blood"), ("DEATHKNIGHT", 251, "death_knight/frost"), ("DEATHKNIGHT", 252, "death_knight/unholy"),
    ("SHAMAN", 262, "shaman/elemental"), ("SHAMAN", 263, "shaman/enhancement"), ("SHAMAN", 264, "shaman/restoration"),
    ("MAGE", 62, "mage/arcane"), ("MAGE", 63, "mage/fire"), ("MAGE", 64, "mage/frost"),
    ("WARLOCK", 265, "warlock/affliction"), ("WARLOCK", 266, "warlock/demonology"), ("WARLOCK", 267, "warlock/destruction"),
    ("MONK", 268, "monk/brewmaster"), ("MONK", 270, "monk/mistweaver"), ("MONK", 269, "monk/windwalker"),
    ("DRUID", 102, "druid/balance"), ("DRUID", 103, "druid/feral"), ("DRUID", 104, "druid/guardian"), ("DRUID", 105, "druid/restoration"),
    ("DEMONHUNTER", 577, "demon_hunter/havoc"), ("DEMONHUNTER", 581, "demon_hunter/vengeance"), ("DEMONHUNTER", 1480, "demon_hunter/devourer"),
    ("EVOKER", 1467, "evoker/devastation"), ("EVOKER", 1468, "evoker/preservation"), ("EVOKER", 1473, "evoker/augmentation"),
]

# Fight styles, in the order the Codex's list toggle cycles through them.
FIGHT_STYLES = [
    ("castingpatchwerk", "Single Target"),
    ("castingpatchwerk3", "3 Targets"),
    ("castingpatchwerk5", "5 Targets"),
]

# Why a spec has no chart, when it has none. Healers: SimC has no healing
# model, so nothing sims them. The rest: bloodmallet only sims specs SimC has
# published a current-tier (MID2) profile for - re-run this script once SimC
# catches up and they will simply appear.
HEALERS = {65, 256, 257, 264, 270, 105, 1468}
HEALER_REASON = ("No trinket sims exist for healing specs: SimulationCraft does not "
                 "simulate healing, so bloodmallet has nothing to rank here.")
NO_PROFILE_REASON = ("bloodmallet has not simulated this spec for the current patch yet "
                     "(SimulationCraft has no current-tier profile for it). Re-run "
                     "tools/fetch_trinkets.py once it does.")

# S/A/B/C by share of the best trinket's gain in the same list.
TIER_CUTOFFS = [("S", 0.90), ("A", 0.78), ("B", 0.62), ("C", 0.0)]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 SpecSage-refresh/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_list(chart):
    data = chart["data"]
    baseline = max(int(v) for v in data["baseline"].values())
    rows = []
    for name in chart["sorted_data_keys"]:
        if name == "baseline":
            continue
        points = data.get(name) or {}
        if not points:
            continue
        ilvl = max(int(k) for k in points)
        dps = points[str(ilvl)]
        gain = (dps - baseline) / baseline * 100.0
        rows.append({
            "name": name,
            "itemID": int(chart["item_ids"][name]),
            "ilvl": ilvl,
            "gain": round(gain, 2),
            "source": chart.get("data_sources", {}).get(name, ""),
            "onUse": bool(chart.get("data_active", {}).get(name, False)),
        })
    rows.sort(key=lambda r: -r["gain"])
    rows = rows[:TOP_N]
    best = rows[0]["gain"] if rows else 0
    for r in rows:
        share = (r["gain"] / best) if best > 0 else 0
        for tier, cutoff in TIER_CUTOFFS:
            if share >= cutoff:
                r["tier"] = tier
                break
    return rows


def main():
    out = []
    out.append("-- Data/Trinkets.lua")
    out.append("-- GENERATED by tools/fetch_trinkets.py - do not hand-edit; re-run the script.")
    out.append("--")
    out.append("-- Per-spec trinket tier lists, from bloodmallet.com's public SimulationCraft")
    out.append("-- trinket sims (bloodmallet is GPL-3.0; the underlying sims are SimC's).")
    out.append("-- Each row is the trinket's simulated DPS gain over the spec's no-trinket")
    out.append("-- baseline at the highest item level it was simulated at, and its S/A/B/C")
    out.append("-- tier is that gain as a share of the best trinket's gain in the same list")
    out.append("-- (S >= 90%, A >= 78%, B >= 62%, C below). A sim ranking, not a claim of")
    out.append("-- what is 'best' for any given fight - see DESIGN.md's \"Trinket tier lists\".")
    out.append("-- Generated: %s UTC" % datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"))
    out.append("")
    out.append("local ADDON, ns = ...")
    out.append("if not ns.GuideStore then return end")
    out.append("")

    counts = {"lists": 0, "unavailable": 0}
    for classToken, specID, slug in SPECS:
        charts = {}
        for style, _ in FIGHT_STYLES:
            url = "https://bloodmallet.com/chart/get/trinkets/%s/%s" % (style, slug)
            try:
                chart = fetch(url)
            except Exception as exc:  # network hiccup: report and move on
                print("  %s %s: %s" % (slug, style, exc), file=sys.stderr)
                chart = {}
            if chart.get("sorted_data_keys"):
                charts[style] = chart
            time.sleep(0.25)

        out.append("-- %s %d (%s)" % (classToken, specID, slug))
        if not charts:
            reason = HEALER_REASON if specID in HEALERS else NO_PROFILE_REASON
            out.append("ns.GuideStore:RegisterTrinkets(%d, { unavailable = %s })" % (specID, lua_str(reason)))
            out.append("")
            counts["unavailable"] += 1
            print("%-12s %5d %-24s unavailable" % (classToken, specID, slug))
            continue

        first = next(iter(charts.values()))
        settings = first.get("simc_settings", {})
        source = ("bloodmallet.com trinket sims, SimulationCraft build %s (%s tier), %s UTC"
                  % (settings.get("simc_hash", "?"), settings.get("tier", "?"), first.get("timestamp", "?")))
        out.append("ns.GuideStore:RegisterTrinkets(%d, {" % specID)
        out.append("  source = %s," % lua_str(source))
        out.append('  patch = "12.1",')
        out.append("  lists = {")
        for style, title in FIGHT_STYLES:
            chart = charts.get(style)
            if not chart:
                continue
            out.append("    { title = %s, fightStyle = %s, list = {" % (lua_str(title), lua_str(style)))
            for r in build_list(chart):
                out.append("      { itemID = %d, name = %s, ilvl = %d, gain = %.2f, tier = %s, source = %s, onUse = %s }," % (
                    r["itemID"], lua_str(r["name"]), r["ilvl"], r["gain"], lua_str(r["tier"]),
                    lua_str(r["source"]), "true" if r["onUse"] else "false"))
            out.append("    }},")
        out.append("  },")
        out.append("})")
        out.append("")
        counts["lists"] += 1
        print("%-12s %5d %-24s %d fight style(s)" % (classToken, specID, slug, len(charts)))

    path = "SpecSage/Data/Trinkets.lua"
    with open(path, "w") as f:
        f.write("\n".join(out))
    print("wrote %s: %d specs with lists, %d unavailable" % (path, counts["lists"], counts["unavailable"]))


if __name__ == "__main__":
    main()
