// tools/wowhead_harvest.js
//
// Harvests Wowhead's per-spec guide data (Best-in-Slot table, trinket tier
// list, talent import codes) for all 40 specs into a JSON dump that
// tools/fetch_bis.py, tools/fetch_trinkets.py and tools/fetch_talents.py
// read as tools/wowhead_dump.json.
//
// Why a browser script and not Python: Wowhead's guide pages are rendered
// client-side and return 403 to any non-browser HTTP client, but a page on
// wowhead.com can fetch its sibling guide pages same-origin, and the guide
// body arrives as Wowhead's own [markup] inside the response, which is what
// this parses. Run it from the browser devtools console (or Claude's Chrome
// tool) on any https://www.wowhead.com/guide/... page:
//
//   1. paste this whole file, which defines window.__harvest and __specs
//   2. await __harvest(0, 8); await __harvest(8, 16); ... up to 40
//      (batches keep each call under a tool/console timeout)
//   3. document.body.innerHTML = '<pre>' + JSON.stringify(window.__ss) + '</pre>'
//      and save the page text as tools/wowhead_dump.json
//
// window.__harvestStats(from, to) is the same thing for the stat-priority
// pages, into window.__sp. It only reads the pages that state the priority as
// a plain ordered list of stat names; roughly a third of them write it as
// free text inside the list items ("Mastery to 1200 rating", "Haste (~700
// Haste)", "Crit = Mastery") or as prose, and those come back with no lists at
// all rather than a guessed ranking. tools/wowhead_stats.json is the reviewed
// transcription of all 40 - use this to spot the pages that changed since,
// then re-read those by hand.
//
// Each spec's record: { updated, talentUpdated, bis: [ { title, rows: [ [slot,
// itemID, name, from], ... ] } ], tiers: [ { tier, items: [ [itemID, source],
// ... ] } ], builds: [ [group, label, code], ... ], err: [...] }. Slot/name
// can be empty for BiS tables that omit a slot column (the Python side
// resolves them from Wowhead's tooltip API); trinket names are resolved the
// same way.

window.__specs = [
  [71,'warrior','arms','dps'],[72,'warrior','fury','dps'],[73,'warrior','protection','tank'],
  [65,'paladin','holy','healing'],[66,'paladin','protection','tank'],[70,'paladin','retribution','dps'],
  [253,'hunter','beast-mastery','dps'],[254,'hunter','marksmanship','dps'],[255,'hunter','survival','dps'],
  [259,'rogue','assassination','dps'],[260,'rogue','outlaw','dps'],[261,'rogue','subtlety','dps'],
  [256,'priest','discipline','healing'],[257,'priest','holy','healing'],[258,'priest','shadow','dps'],
  [250,'death-knight','blood','tank'],[251,'death-knight','frost','dps'],[252,'death-knight','unholy','dps'],
  [262,'shaman','elemental','dps'],[263,'shaman','enhancement','dps'],[264,'shaman','restoration','healing'],
  [62,'mage','arcane','dps'],[63,'mage','fire','dps'],[64,'mage','frost','dps'],
  [265,'warlock','affliction','dps'],[266,'warlock','demonology','dps'],[267,'warlock','destruction','dps'],
  [268,'monk','brewmaster','tank'],[270,'monk','mistweaver','healing'],[269,'monk','windwalker','dps'],
  [102,'druid','balance','dps'],[103,'druid','feral','dps'],[104,'druid','guardian','tank'],[105,'druid','restoration','healing'],
  [577,'demon-hunter','havoc','dps'],[581,'demon-hunter','vengeance','tank'],[1480,'demon-hunter','devourer','dps'],
  [1467,'evoker','devastation','dps'],[1468,'evoker','preservation','healing'],[1473,'evoker','augmentation','dps'],
];
window.__ss = window.__ss || {};

window.__harvest = async function (from, to) {
  // The guide body is a JS string in the page: unescape it, then strip the
  // HTML the renderer already produced so only Wowhead's [markup] remains
  // to match against (both forms carry the same [item=] / [copy=] tags).
  const un = s => s.replace(/\\"/g, '"').replace(/\\\//g, '/').replace(/\\r\\n|\\n|\\t/g, ' ');
  const plain = s => s.replace(/\[[^\]]*\]/g, '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
  const log = [];
  for (let k = from; k < to && k < window.__specs.length; k++) {
    const [spec, cls, sp, role] = window.__specs[k];
    const rec = { bis: [], tiers: [], builds: [], err: [] };
    try {
      const raw = un(await (await fetch(`/guide/classes/${cls}/${sp}/bis-gear`, { credentials: 'same-origin' })).text());
      rec.updated = (raw.match(/Updated:\s*(?:<[^>]*>\s*)?([\d\/]+)/) || [])[1] || null;
      // BiS tables: every [table] whose first row mentions Slot or Item.
      for (const tbl of raw.split(/\[table[^\]]*\]/).slice(1)) {
        const body = tbl.slice(0, tbl.indexOf('[/table]') > 0 ? tbl.indexOf('[/table]') : 20000);
        const trs = body.split(/\[tr[^\]]*\]/).slice(1);
        if (!trs.length || !/Slot|Item/.test(plain(trs[0]))) continue;
        const headCells = trs[0].split(/\[td[^\]]*\]/).slice(1).map(plain);
        const slotCol = headCells.findIndex(c => /Slot/.test(c));
        const rows = [];
        for (const tr of trs.slice(1)) {
          const cells = tr.split(/\[td[^\]]*\]/).slice(1);
          const itemCell = cells.findIndex(c => /\[item=\d+/.test(c));
          if (itemCell < 0) continue;
          const id = +cells[itemCell].match(/\[item=(\d+)/)[1];
          const slot = slotCol >= 0 && cells[slotCol] !== undefined ? plain(cells[slotCol]) : '';
          const from = plain(cells.slice(itemCell + 1).join(' '));
          rows.push([slot, id, '', from]);
        }
        if (rows.length) {
          // Title: the nearest [h2]/[h3] heading before this table.
          const before = raw.slice(0, raw.indexOf(tbl));
          const hm = [...before.matchAll(/\[h[23][^\]]*\]([\s\S]*?)\[\/h[23]\]/g)].pop();
          rec.bis.push({ title: hm ? plain(hm[1]).slice(0, 80) : '', rows });
        }
      }
      // Trinket tier list: one ranking; each badge carries its source tag.
      const ti = raw.indexOf('[tier-list');
      if (ti >= 0) {
        const te = raw.indexOf('[/tier-list', ti);
        const seg = raw.slice(ti, te > 0 ? te : ti + 40000);
        for (const tier of seg.split('[tier]').slice(1)) {
          const label = (tier.match(/\[tier-label[^\]]*\]\s*([SABCDF])\s*\[\/tier-label\]/) || [])[1];
          if (!label) continue;
          const items = [...tier.matchAll(/\[icon-badge=(\d+)([^\]]*)\]/g)]
            .map(m => [+m[1], (m[2].match(/display-options=([a-z,]+)/) || [])[1] || '']);
          rec.tiers.push({ tier: label, items });
        }
      }
    } catch (e) { rec.err.push('bis:' + String(e).slice(0, 80)); }
    try {
      let resp = null;
      for (const r of (role === 'healing' ? ['healer', 'healing'] : [role])) {
        resp = await fetch(`/guide/classes/${cls}/${sp}/talent-builds-pve-${r}`, { credentials: 'same-origin' });
        if (resp.status === 200) break;
      }
      const raw = un(await resp.text());
      rec.talentUpdated = (raw.match(/Updated:\s*(?:<[^>]*>\s*)?([\d\/]+)/) || [])[1] || null;
      // Import-code tables: [copy="Label"]CODE[/copy], grouped under the
      // nearest preceding [h3] (the hero tree) when there is one.
      const seen = new Set();
      for (const m of raw.matchAll(/\[copy="([^"]+)"\]\s*([A-Za-z0-9+\/]{60,})\s*\[\/copy\]/g)) {
        if (seen.has(m[2])) continue;
        seen.add(m[2]);
        const before = raw.slice(Math.max(0, m.index - 4000), m.index);
        const hm = [...before.matchAll(/\[h3[^\]]*\]([\s\S]*?)\[\/h3\]/g)].pop();
        rec.builds.push([hm ? plain(hm[1]).slice(0, 40) : '', m[1].trim(), m[2]]);
      }
      // Fallback for pages that render the table to HTML instead.
      if (!rec.builds.length) {
        for (const m of raw.matchAll(/<b>([^<]{2,60})<\/b>[\s\S]{0,400}?talent-calc\/blizzard\/([A-Za-z0-9+\/]{60,})/g)) {
          if (seen.has(m[2]) || m[1] === 'Build') continue;
          seen.add(m[2]);
          rec.builds.push(['', m[1].trim(), m[2]]);
        }
      }
    } catch (e) { rec.err.push('talents:' + String(e).slice(0, 80)); }
    window.__ss[spec] = rec;
    log.push(`${spec}:${rec.bis.map(b => b.rows.length).join('/') || 0}b ${rec.tiers.length}t ${rec.builds.length}c${rec.err.length ? ' ERR ' + rec.err.join(';') : ''}`);
  }
  return log.join(' | ');
};

window.__sp = window.__sp || {};

// Per-hero-tree stat priorities: every [ol]/[ul] on a spec's stat-priority
// page whose items are all bare stat names, labelled with the nearest [b]
// before it (Wowhead's own "<Hero Tree> Stat Priority" caption).
window.__harvestStats = async function (from, to) {
  const un = s => s.replace(/\\"/g, '"').replace(/\\\//g, '/').replace(/\\r\\n|\\n|\\t/g, ' ');
  const plain = s => s.replace(/\[[^\]]*\]/g, '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
  const STAT = /^(intellect|strength|agility|primary stat|stamina|armor|critical strike|crit|haste|mastery|versatility|leech|avoidance|speed)$/i;
  const log = [];
  for (let k = from; k < to && k < window.__specs.length; k++) {
    const [spec, cls, sp, role] = window.__specs[k];
    const rec = { lists: [], err: [] };
    try {
      let resp = null;
      for (const r of (role === 'healing' ? ['healer', 'healing'] : [role])) {
        rec.url = `/guide/classes/${cls}/${sp}/stat-priority-pve-${r}`;
        resp = await fetch(rec.url, { credentials: 'same-origin' });
        if (resp.status === 200) break;
      }
      const raw = un(await resp.text());
      rec.updated = (raw.match(/Updated:\s*(?:<[^>]*>\s*)?([\d\/]+)/) || [])[1] || null;
      for (const m of raw.matchAll(/\[(ol|ul)\]([\s\S]*?)\[\/\1\]/g)) {
        const items = [...m[2].matchAll(/\[li\]([\s\S]*?)\[\/li\]/g)].map(x => plain(x[1]));
        if (items.length < 3 || !items.every(t => STAT.test(t))) continue;
        const before = raw.slice(Math.max(0, m.index - 400), m.index);
        const bm = [...before.matchAll(/\[b\]([\s\S]*?)\[\/b\]/g)].pop();
        rec.lists.push({ label: bm ? plain(bm[1]).slice(0, 60) : '', stats: items });
      }
    } catch (e) { rec.err.push(String(e).slice(0, 80)); }
    window.__sp[spec] = rec;
    log.push(`${spec}:${rec.lists.length}${rec.err.length ? ' ERR' : ''}`);
  }
  return log.join(' ');
};
