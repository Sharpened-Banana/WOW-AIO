#!/usr/bin/env python3
"""Regenerates SpecSage/Data/Trinkets.lua from two public sources.

1. bloodmallet.com (github.com/Bloodmallet/bloodmallet_web_frontend, GPL-3.0)
   runs SimulationCraft trinket sims for every spec SimC has a current-tier
   profile for and exposes the result as JSON:

       https://bloodmallet.com/chart/get/trinkets/<fight style>/<class>/<spec>

   Each response carries, per trinket, the simulated DPS at every item level
   it was run at, plus the trinket's itemID, source (Raid/Dungeon/Profession/
   PvP) and whether it is an on-use ("active") trinket. That becomes one list
   per fight style below: the top TOP_N trinkets, each scored as a percentage
   gain over the spec's baseline (no trinket) and bucketed into an S/A/B/C
   tier by how close it sits to the best trinket's gain.

2. icy-veins.com's per-spec gear guide, whose "Trinket Rankings" table is an
   editorial S..D tier list with wowhead item IDs on every entry. It covers
   all 40 specs - including the healers SimC cannot sim and the specs SimC
   has no current-tier profile for yet - so it becomes an extra "Icy Veins"
   list on every spec, and every sim row also carries Icy Veins' tier for the
   same item (`siteTier`) so the two views sit side by side. Where Icy Veins
   rates something S that the sims never ran (or ranked outside the top
   TOP_N), the spec gets a `note` saying so rather than the disagreement
   being smoothed over. (Wowhead's guide pages render client-side and refuse
   plain HTTP clients, so they could not be read the same way.)

Run from the repo root:  python3 tools/fetch_trinkets.py
"""

import datetime
import html
import json
import re
import sys
import time
import urllib.request

sys.path.insert(0, "tools")
import wowhead  # noqa: E402

TOP_N = 15
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"

# (classToken, specID, bloodmallet slug, icy-veins slug, icy-veins role)
SPECS = [
    ("WARRIOR", 71, "warrior/arms", "arms-warrior", "dps"),
    ("WARRIOR", 72, "warrior/fury", "fury-warrior", "dps"),
    ("WARRIOR", 73, "warrior/protection", "protection-warrior", "tank"),
    ("PALADIN", 65, "paladin/holy", "holy-paladin", "healing"),
    ("PALADIN", 66, "paladin/protection", "protection-paladin", "tank"),
    ("PALADIN", 70, "paladin/retribution", "retribution-paladin", "dps"),
    ("HUNTER", 253, "hunter/beast_mastery", "beast-mastery-hunter", "dps"),
    ("HUNTER", 254, "hunter/marksmanship", "marksmanship-hunter", "dps"),
    ("HUNTER", 255, "hunter/survival", "survival-hunter", "dps"),
    ("ROGUE", 259, "rogue/assassination", "assassination-rogue", "dps"),
    ("ROGUE", 260, "rogue/outlaw", "outlaw-rogue", "dps"),
    ("ROGUE", 261, "rogue/subtlety", "subtlety-rogue", "dps"),
    ("PRIEST", 256, "priest/discipline", "discipline-priest", "healing"),
    ("PRIEST", 257, "priest/holy", "holy-priest", "healing"),
    ("PRIEST", 258, "priest/shadow", "shadow-priest", "dps"),
    ("DEATHKNIGHT", 250, "death_knight/blood", "blood-death-knight", "tank"),
    ("DEATHKNIGHT", 251, "death_knight/frost", "frost-death-knight", "dps"),
    ("DEATHKNIGHT", 252, "death_knight/unholy", "unholy-death-knight", "dps"),
    ("SHAMAN", 262, "shaman/elemental", "elemental-shaman", "dps"),
    ("SHAMAN", 263, "shaman/enhancement", "enhancement-shaman", "dps"),
    ("SHAMAN", 264, "shaman/restoration", "restoration-shaman", "healing"),
    ("MAGE", 62, "mage/arcane", "arcane-mage", "dps"),
    ("MAGE", 63, "mage/fire", "fire-mage", "dps"),
    ("MAGE", 64, "mage/frost", "frost-mage", "dps"),
    ("WARLOCK", 265, "warlock/affliction", "affliction-warlock", "dps"),
    ("WARLOCK", 266, "warlock/demonology", "demonology-warlock", "dps"),
    ("WARLOCK", 267, "warlock/destruction", "destruction-warlock", "dps"),
    ("MONK", 268, "monk/brewmaster", "brewmaster-monk", "tank"),
    ("MONK", 270, "monk/mistweaver", "mistweaver-monk", "healing"),
    ("MONK", 269, "monk/windwalker", "windwalker-monk", "dps"),
    ("DRUID", 102, "druid/balance", "balance-druid", "dps"),
    ("DRUID", 103, "druid/feral", "feral-druid", "dps"),
    ("DRUID", 104, "druid/guardian", "guardian-druid", "tank"),
    ("DRUID", 105, "druid/restoration", "restoration-druid", "healing"),
    ("DEMONHUNTER", 577, "demon_hunter/havoc", "havoc-demon-hunter", "dps"),
    ("DEMONHUNTER", 581, "demon_hunter/vengeance", "vengeance-demon-hunter", "tank"),
    ("DEMONHUNTER", 1480, "demon_hunter/devourer", "devourer-demon-hunter", "dps"),
    ("EVOKER", 1467, "evoker/devastation", "devastation-evoker", "dps"),
    ("EVOKER", 1468, "evoker/preservation", "preservation-evoker", "healing"),
    ("EVOKER", 1473, "evoker/augmentation", "augmentation-evoker", "dps"),
]

# Sim fight styles, in the order the Codex's list toggle cycles through them;
# the Icy Veins list comes last.
FIGHT_STYLES = [
    ("castingpatchwerk", "Single Target"),
    ("castingpatchwerk3", "3 Targets"),
    ("castingpatchwerk5", "5 Targets"),
]

HEALERS = {65, 256, 257, 264, 270, 105, 1468}
HEALER_NOTE = ("No sim list: SimulationCraft does not simulate healing, so bloodmallet has "
               "nothing to rank for this spec. The Icy Veins ranking is the only list here.")
NO_PROFILE_NOTE = ("No sim list yet: bloodmallet has not simulated this spec for the current patch "
                   "(SimulationCraft has no current-tier profile for it). The Icy Veins ranking is "
                   "the only list here until it does.")

# S/A/B/C by share of the best trinket's gain in the same list.
TIER_CUTOFFS = [("S", 0.90), ("A", 0.78), ("B", 0.62), ("C", 0.0)]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", errors="ignore")


def fetch_json(url):
    return json.loads(fetch(url))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- bloodmallet ------------------------------------------------------------

def build_sim_list(chart):
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


# --- icy-veins --------------------------------------------------------------

def parse_icy_veins(body):
    """Returns (tiers, updated): tiers = [ { tier, items: [ {itemID, name} ] } ]."""
    i = body.find("Trinket Rankings")
    if i < 0:
        m2 = re.search(r'<h2 id="trinkets?"', body)
        i = m2.start() if m2 else -1
    if i < 0:
        return None, None
    m = re.search(r'guide-header__updated-date[^>]*>([^<]+)<', body)
    updated = m.group(1).strip() if m else None
    seg = body[i:]
    seg = seg[seg.find("<table>"):] if "<table>" in seg else seg
    end = seg.find("</table>")
    seg = seg[:end] if end > 0 else seg[:20000]
    tiers = []
    for row in re.findall(r"<tr>(.*?)</tr>", seg, re.S):
        tm = re.search(r"<strong>([SABCDF])\s*Tier</strong>", row)
        if not tm:
            continue
        # One trinket per entry. Entries come in two shapes on the site: a
        # <details class="list-item"> whose <summary> names the trinket (its
        # expanded description can mention other items - Havoc's S-tier
        # entry names the weapon it pairs with, Unholy's names its BiS weapon
        # - and those are not trinkets in the tier), or a bare <li> with the
        # item link and a dash of text. Take the first item link of each
        # <summary>, then of each <li> left once the <details> are removed.
        link = r'data-wowhead="item=(\d+)[^"]*"[^>]*>([^<]+)<'
        units = re.findall(r"<summary>(.*?)</summary>", row, re.S)
        remainder = re.sub(r"<details.*?</details>", "", row, flags=re.S)
        units += re.findall(r"<li[ >](.*?)</li>", remainder, re.S)
        seen, items = set(), []
        for unit in units:
            m = re.search(link, unit)
            if not m:
                continue
            iid = int(m.group(1))
            if iid in seen:
                continue
            seen.add(iid)
            items.append({"itemID": iid, "name": html.unescape(m.group(2)).strip()})
        tiers.append({"tier": tm.group(1), "items": items})
    return (tiers or None), updated


# --- output -----------------------------------------------------------------

# itemID -> bonus-ID list, written by tools/fetch_bis.py from the bonus lists
# Icy Veins puts on its BiS links. Neither trinket source publishes one (see
# Data/BiS.lua's header for why they matter), so a trinket only gets one when
# some spec's BiS guide names the same item; the rest stay bare.
def _bonus_map():
    try:
        return {int(k): v for k, v in json.load(open("tools/item_bonus.json")).items()}
    except (OSError, ValueError):
        return {}


BONUS_BY_ITEM = _bonus_map()


def emit_row(r):
    parts = ["itemID = %d" % r["itemID"], "name = %s" % lua_str(r["name"])]
    bonus = BONUS_BY_ITEM.get(r["itemID"])
    if bonus:
        parts.append("bonus = %s" % lua_str(bonus))
    if r.get("ilvl"):
        parts.append("ilvl = %d" % r["ilvl"])
    if r.get("gain") is not None:
        parts.append("gain = %.2f" % r["gain"])
    parts.append("tier = %s" % lua_str(r["tier"]))
    if r.get("siteTier"):
        parts.append("siteTier = %s" % lua_str(r["siteTier"]))
    if r.get("whTier"):
        parts.append("whTier = %s" % lua_str(r["whTier"]))
    if r.get("source"):
        parts.append("source = %s" % lua_str(r["source"]))
    if r.get("onUse") is not None:
        parts.append("onUse = %s" % ("true" if r["onUse"] else "false"))
    return "      { " + ", ".join(parts) + " },"


def main():
    out = []
    out.append("-- Data/Trinkets.lua")
    out.append("-- GENERATED by tools/fetch_trinkets.py - do not hand-edit; re-run the script.")
    out.append("--")
    out.append("-- Per-spec trinket tier lists from two public sources, side by side:")
    out.append("--  * bloodmallet.com's SimulationCraft trinket sims (bloodmallet is GPL-3.0;")
    out.append("--    the sims are SimC's): each row is the trinket's simulated DPS gain over")
    out.append("--    the spec's no-trinket baseline at the highest item level it was simmed")
    out.append("--    at, tiered S/A/B/C by share of the best trinket's gain in the same list")
    out.append("--    (S >= 90%, A >= 78%, B >= 62%, C below). `siteTier` on a sim row is Icy")
    out.append("--    Veins' tier for the same item, when they list it; `whTier` is Wowhead's.")
    out.append("--  * icy-veins.com's per-spec \"Trinket Rankings\" table, an editorial S..D")
    out.append("--    tier list, as its own list on every spec (the only sim-free list for")
    out.append("--    healers and for specs SimC has no current-tier profile for yet).")
    out.append("--  * wowhead.com's per-spec trinket tier list (S..F, harvested in a browser by")
    out.append("--    tools/wowhead_harvest.js into tools/wowhead_dump.json), as its own list.")
    out.append("-- A `note` records where the two disagree. Neither is a verdict for any given")
    out.append("-- fight - see DESIGN.md's \"Trinket tier lists\".")
    out.append("-- Generated: %s UTC" % datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M"))
    out.append("")
    out.append("local ADDON, ns = ...")
    out.append("if not ns.GuideStore then return end")
    out.append("")

    counts = {"sim": 0, "iv": 0, "wh": 0, "notes": 0}
    dump = wowhead.load()
    for classToken, specID, bmSlug, ivSlug, ivRole in SPECS:
        charts = {}
        for style, _ in FIGHT_STYLES:
            url = "https://bloodmallet.com/chart/get/trinkets/%s/%s" % (style, bmSlug)
            try:
                chart = fetch_json(url)
            except Exception as exc:
                print("  %s %s: %s" % (bmSlug, style, exc), file=sys.stderr)
                chart = {}
            if chart.get("sorted_data_keys"):
                charts[style] = chart
            time.sleep(0.25)

        ivURL = "https://www.icy-veins.com/wow/%s-pve-%s-gear-best-in-slot" % (ivSlug, ivRole)
        ivTiers, ivUpdated = None, None
        try:
            ivTiers, ivUpdated = parse_icy_veins(fetch(ivURL))
        except Exception as exc:
            print("  %s: %s" % (ivURL, exc), file=sys.stderr)
        time.sleep(0.5)

        ivTierOf = {}
        for t in (ivTiers or []):
            for it in t["items"]:
                ivTierOf.setdefault(it["itemID"], t["tier"])
        whTiers = wowhead.trinket_tiers(dump, specID)
        whTierOf = {}
        for t in whTiers:
            for it in t["items"]:
                whTierOf.setdefault(it["itemID"], t["tier"])

        out.append("-- %s %d (%s | %s)" % (classToken, specID, bmSlug, ivSlug))
        if not charts and not ivTiers and not whTiers:
            out.append("ns.GuideStore:RegisterTrinkets(%d, { unavailable = %s })" % (
                specID, lua_str("neither bloodmallet nor Icy Veins had a trinket list for this spec when "
                                "tools/fetch_trinkets.py last ran")))
            out.append("")
            print("%-12s %5d %-24s NOTHING" % (classToken, specID, bmSlug))
            continue

        sources = []
        if charts:
            first = next(iter(charts.values()))
            settings = first.get("simc_settings", {})
            sources.append("bloodmallet.com trinket sims, SimulationCraft build %s (%s tier), %s UTC"
                           % (settings.get("simc_hash", "?"), settings.get("tier", "?"), first.get("timestamp", "?")))
        if ivTiers:
            sources.append("Icy Veins %s gear guide, updated %s" % (ivSlug.replace("-", " ").title(), ivUpdated or "?"))
        if whTiers:
            sources.append("Wowhead %s gear guide, updated %s" % (ivSlug.replace("-", " ").title(),
                                                                 wowhead.updated(dump, specID) or "?"))

        out.append("ns.GuideStore:RegisterTrinkets(%d, {" % specID)
        out.append("  source = %s," % lua_str("; ".join(sources)))
        out.append('  patch = "12.1",')

        notes = []
        if not charts:
            notes.append(HEALER_NOTE if specID in HEALERS else NO_PROFILE_NOTE)
        simIDs = set()
        out.append("  lists = {")
        for style, title in FIGHT_STYLES:
            chart = charts.get(style)
            if not chart:
                continue
            rows = build_sim_list(chart)
            out.append("    { title = %s, fightStyle = %s, list = {" % (lua_str(title), lua_str(style)))
            for r in rows:
                r["siteTier"] = ivTierOf.get(r["itemID"])
                r["whTier"] = whTierOf.get(r["itemID"])
                simIDs.add(r["itemID"])
                out.append(emit_row(r))
            out.append("    }},")
        if ivTiers:
            out.append("    { title = \"Icy Veins\", fightStyle = \"icyveins\", list = {")
            for t in ivTiers:
                for it in t["items"]:
                    out.append(emit_row({"itemID": it["itemID"], "name": it["name"], "tier": t["tier"]}))
            out.append("    }},")
        if whTiers:
            out.append("    { title = \"Wowhead\", fightStyle = \"wowhead\", list = {")
            for t in whTiers:
                for it in t["items"]:
                    out.append(emit_row({"itemID": it["itemID"], "name": it["name"], "tier": t["tier"],
                                         "source": it["source"]}))
            out.append("    }},")
        out.append("  },")

        if charts:
            for siteName, siteTiers in (("Icy Veins", ivTiers or []), ("Wowhead", whTiers)):
                missing = [it["name"] for t in siteTiers if t["tier"] == "S"
                           for it in t["items"] if it["itemID"] not in simIDs]
                if missing:
                    notes.append("%s also rates %s S-tier, which the sims either did not run or "
                                 "ranked outside the top %d - worth a look if you have it."
                                 % (siteName, ", ".join(missing), TOP_N))
        if notes:
            out.append("  note = %s," % lua_str(" ".join(notes)))
            counts["notes"] += 1
        out.append("})")
        out.append("")
        if charts:
            counts["sim"] += 1
        if ivTiers:
            counts["iv"] += 1
        if whTiers:
            counts["wh"] += 1
        print("%-12s %5d %-24s sim=%d IV=%s WH=%s%s" % (classToken, specID, bmSlug, len(charts),
              "yes" if ivTiers else "no", "yes" if whTiers else "no", " (note)" if notes else ""))

    path = "SpecSage/Data/Trinkets.lua"
    with open(path, "w") as f:
        f.write("\n".join(out))
    print("wrote %s: %d specs with sim lists, %d with an Icy Veins list, %d with a Wowhead list, %d with notes"
          % (path, counts["sim"], counts["iv"], counts["wh"], counts["notes"]))


if __name__ == "__main__":
    main()
