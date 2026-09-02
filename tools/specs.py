"""Shared spec table and fetch helper for the tools/ generators."""
import json
import urllib.request

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


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", errors="ignore")


def fetch_json(url):
    return json.loads(fetch(url))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def icy_veins_updated(body):
    import re
    m = re.search(r'guide-header__updated-date[^>]*>([^<]+)<', body)
    return m.group(1).strip() if m else None
