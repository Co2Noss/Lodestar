<p align="center">
  <img src="docs/logo.png" alt="Lodestar" width="220">
</p>

<h1 align="center">Lodestar</h1>

<p align="center"><strong>Find what matters. Ignore the rest.</strong></p>

<p align="center">
  A decision engine for World of Warcraft. Blizzard shows you everything you can do.<br>
  Lodestar tells you what is worth doing next.
</p>

<p align="center">
  <a href="https://discord.gg/a7hrHavcwq"><img src="https://img.shields.io/discord/1541817004531646555?color=7289DA&label=DISCORD&logo=discord&style=for-the-badge" alt="Discord"></a>
  <a href="https://github.com/Co2Noss/Lodestar"><img src="https://img.shields.io/github/stars/Co2Noss/Lodestar?style=for-the-badge&label=GitHub%20Stars%20%E2%AD%90&logo=github&color=yellow" alt="GitHub Stars"></a>
  <a href="https://www.curseforge.com/wow/addons/lodestar-guide"><img src="https://cf.way2muchnoise.eu/full_1667135_Downloads.svg?badge_style=for_the_badge" alt="CurseForge Downloads"></a>
  <a href="https://github.com/Co2Noss/Lodestar/releases"><img src="https://img.shields.io/github/v/release/Co2Noss/Lodestar?style=for-the-badge&logo=github" alt="GitHub Release"></a>
</p>

## Download

[![CurseForge](https://img.shields.io/badge/CurseForge-FF784D?style=for-the-badge&logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/lodestar-guide)
[![GitHub](https://img.shields.io/badge/GitHub-121013?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Co2Noss/Lodestar)
[![GitHub Release](https://img.shields.io/badge/GitHub%20Release-121013?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Co2Noss/Lodestar/releases)

## Community

[![Discord](https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/a7hrHavcwq)
[![Issues](https://img.shields.io/badge/GitHub%20Issues-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Co2Noss/Lodestar/issues)

## Donate

[![PayPal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](http://paypal.me/Co2Noss)

Lodestar answers one question: what is the best use of your next hour in World of Warcraft?

## Optional addons

Lodestar works on its own. These addons unlock extra behaviour if they are loaded:

- **TradeSkillMaster, Auctionator, RECrystallize** — gold prices. Without one, gold making stays quiet. Lodestar does not invent an auction house.
- **TomTom** — multiple waypoints and a closest-arrow. Without it, Lodestar uses the client's single map pin.
- **HandyNotes** plus a notes pack — nearby rares and treasures those packs are currently showing. [HandyNotes](https://www.curseforge.com/wow/addons/handynotes) by itself has no coordinates; packs such as [Midnight](https://www.curseforge.com/wow/addons/handynotes-midnight) and [Silvermoon](https://www.curseforge.com/wow/addons/handynotes-silvermoon) (and many others) supply the pins. Known rewards stay hidden if the pack hid them. Without a pack, Lodestar stays quiet about rares.
- **ElvUI** — the ElvUI theme reads ElvUI's live backdrop, border, texture and font.

## First login

Lodestar asks what you care about before it recommends anything. Every goal starts off, the
window opens on the welcome page at your first login, and nothing is ranked until you pick at
least one goal. It says there and then that Settings can change your answer at any time.

The reason it asks instead of guessing: a goal that is off silently removes recommendations,
and a player who never chose those defaults has no way to know what is missing.

Existing installs are left alone. Goals you already chose count as an answer, so the welcome
page never interrupts an upgrade.

## Pages

- **Today** — recommendations matching your goals, ranked best first and split into tabs by where the work happens. The last tab you were on is remembered. Mount farms sit on their own tab when that goal is on.
- **Great Vault** — Raid, Dungeons and World each have their own tab, with every slot, its current reward quality, and what would improve it. If last week's chest is still sitting there, Today tells you to claim it.
- **Professions** — one tab per trained profession, including Cooking, Fishing and Archaeology: skill, unspent knowledge, points already spent, weekly quests, drops, treasures and catch-up. Click a profession to open it. Specializations is there for trees. Secondaries have no knowledge tree, so they show skill.
- **Warband** — every character Lodestar has seen, with vault and knowledge status.
- **Settings** — split into Goals, Reputation, Appearance, Compact and Layout, so each group is a click rather than a scroll. The last tab you were on is remembered.

## Ranking and categories

Recommendations are scored against the goals you chose on first login, which Settings can
change at any time, then grouped by where the work happens: Great Vault, Professions,
Mounts, Reputation, Solo content, Questing. Today, Great Vault, Professions and Settings each use
the same tab strip, so moving between groups is a click rather than a scroll. Tab order on
Today is stable; the work inside a tab is still ranked best first. The last tab on each
page is remembered.

Every card shows its priority, estimated time and score. Priority is High, Medium or Low.
Unspent knowledge, weekly lockouts and an unclaimed Great Vault are High, because missing
them costs something this week. Gathering and unfinished secondaries are Medium. Treasures,
HandyNotes rares, catch-up, dungeon mount farms, unfinished reputations and gold farms are Low, because they
wait. Score still decides the order.

There is no time budget. Lodestar ranks and groups everything instead of asking how long you
have and hiding whatever does not fit.

## Great Vault accuracy

Slots report a real difficulty or tier, never a raw difficulty ID. Upgrade effort is counted
from the runs and boss kills you have actually banked this week, so "complete 4 delves at
Tier 8 or higher" reflects what is left rather than a guess.

A slot is only called maxed when it reaches the tier cap in `LS.tierCaps` or the highest
tier you have personally cleared. Edit that table when a patch changes the cap.

If last week's Great Vault is still unclaimed after Tuesday reset, Today ranks that first:
open the vault and pick a reward from each filled slot. Filling this week's chest is a
separate job.

A Bountiful Delve stays off Today once the World Vault is finished, you have no Restored
Coffer Keys, you cannot make another key from shards, and this week's T11 Gilded Stashes
are done.

## Professions and knowledge

Only professions this character has trained are listed, filtered to the current expansion by
default: the two primaries, plus Cooking, Fishing and Archaeology when those slots are filled.
Skill level, unspent knowledge, points already spent and remaining tree cost come from live
APIs and are always accurate. Click a profession to open its window; professions with a
knowledge tree also have a Specializations button. Cooking, Fishing and Archaeology have no
knowledge tree, so the page shows skill, and Today recommends leveling them until they are
at the cap. Recipe lists and specialization builds stay in the profession window; Lodestar
ranks what is still worth doing, then Specializations opens the live tree.

Knowledge is split by what it actually asks of you:

- **Weekly quests** — treatises and trainer or Consortium quests. Where a trainer offers several
  quests but only rewards one, that counts as a single task.
- **Weekly drops** — knowledge that drops while gathering, mining, skinning or disenchanting.
- **Treasures** — eight one-time world pickups per Midnight profession, plus vendor books.
  They never expire.
- **Catch-up** — for gathering professions and Enchanting this unlocks once the week's fixed
  sources are exhausted, so the page shows which gates are still closed. For crafting professions
  it comes from Patron Orders, which the client does not expose, so it is described rather than
  counted.

`Knowledge.lua` carries every source for Midnight and The War Within, keyed by profession skill
line variant ID. The quest IDs were checked against
[WeeklyKnowledge](https://github.com/DennisRas/WeeklyKnowledge), which maintains the community
data set for this. When a patch adds sources, add them to that file or register them at runtime:

```lua
Lodestar:RegisterKnowledge(2918, {
  objectives = {
    { kind = "TREATISE", label = "Treatise", quests = { 95137 }, points = 1 },
    { kind = "WEEKLY", label = "Trainer quest", quests = { 93697, 93698, 93699 }, points = 3, limit = 1 },
    { kind = "TREASURE", label = "Embroidered Memento", quests = { 93542 }, points = 2 },
  },
})
```

`kind` is `TREATISE`, `WEEKLY` or `GATHERING` for sources that reset weekly, and `TREASURE` for
one-time pickups. `limit` caps how many quests in the set can count. Anything with no data says so
rather than reporting itself complete.

## Mounts

The Mounts goal ranks farms you have not collected yet. Weekly raid and world-boss lockouts
come first, because missing the week spends the roll: if you do not have Invincible and
Icecrown Citadel 25 Heroic is still open, it is on the plan; if you already own it, or
already killed the Lich King on that lockout, it stays off. Heroic dungeon farms with no
weekly lockout still appear, as Low.

The farm list lives in `Mounts.lua`. It is the collector circuit, not every mount in the
game. Add a row there when a drop is worth a weekly check.

## Reputation

The Reputation goal ranks factions from the live reputation list, grouped by expansion and
category. Settings → Reputation gives each expansion its own tab, then the categories and
factions under it. Nothing is assumed: turn on an expansion, a category, or a single
faction. Exalted standings and capped renown stay off the plan. Paragon chests that are
waiting still appear.

## Gold making

The Gold making goal ranks gathering you have trained, cloth from humanoids, and a few pet
farms that never expire. Herbalism, Mining and Skinning each get Midnight and Khaz Algar
loops. Tailors get Midnight and Khaz Algar cloth; anyone can farm older cloth such as
Frostweave and Netherweave. Prices come from **TSM**, **Auctionator** or **RECrystallize**.
Lodestar does not invent an auction house. Settings → Goals lets you pick the source: Auto
uses the first of those addons that is loaded. If none is loaded, or the one you picked is
not, Lodestar stays quiet about gold.

The farm list lives in `Gold.lua`. It is the collector circuit, not every node in the game.

## Compact mode

A small window that sits on your screen with the next thing to do, or two when more than
one goal is on. Each row shows its priority, estimated time and score. Turn it on in
Settings, with `/ls compact`, or by right-clicking the minimap button.

- Click an entry to open its details page. Double click anywhere to open the full window.
- Single recommendation mode keeps it to one row even when several goals are on.
- Height follows the number of rows: one goal contracts it, a second goal expands it, and
  collapsing in combat leaves just the title bar.
- It hides while the full window is open and comes back when you close it.
- Drag to move, drag the right edge to set the width. Both are saved.

Priority is High, Medium or Low. Unspent knowledge is High because spending it is free. A
one-time treasure is Low because it waits.

## Themes

The Blizzard theme uses the client's own frame art, the modern panel style Dragonflight
introduced, along with Blizzard's real font colours rather than approximations of them. If a
client ever stops offering that art, the theme falls back to a flat frame in the same colours
instead of rendering without a border.

With ElvUI loaded, the ElvUI theme reads ElvUI's own backdrop colour, border colour, status
bar texture and font. Ellesmere and Minimal are standalone palettes.

## Colors

Settings → Appearance lists every colour the interface uses — accent, text, background,
panels, cards, borders, warnings and muted text — and clicking one opens Blizzard's colour
picker.

Your choices override whatever the theme resolved to, including ElvUI's live media, and
survive switching themes, so a theme change never silently discards them. Rows you have
changed are marked, and "Reset colors to the theme" drops all of them at once. Colours you
have not touched keep following the active theme.

## Window

Drag the frame to move it. Drag the grip in the bottom-right corner to resize it. Size and
position are saved. Escape closes the main window; compact mode stays up.

## Commands

- `/ls` — open or close the window
- `/ls theme auto` (also blizzard, elvui, ellesmere, minimal)
- `/ls compact`
- `/ls compact single`
- `/ls debug` — disable every other addon and reload, so you can tell if an error is Lodestar
- `/ls debug off` — turn those addons back on (this character only)
- `/ls reset`

## Waypoints

Treasure recommendations that have a known location get a **Waypoint** button. With
[TomTom](https://www.curseforge.com/wow/addons/tomtom) loaded, that pins every remaining
pickup and points the arrow at the closest. Without TomTom, Lodestar uses the client's one
map pin and super-tracks it.

HandyNotes rares get the same button: Lodestar pins what a HandyNotes notes pack is
currently showing in your zone, not a separate spawn list. HandyNotes by itself has no
coordinates; Midnight, Silvermoon, and other packs supply the pins.

Midnight gathering farms get a **Map** button that opens the zone circuit (Eversong Woods →
Zul'Aman → Harandar → Voidstorm). Node-by-node herb/ore routes are not invented; those pins
only appear when coordinates are in the data.

Coordinates for profession treasures come from
[WeeklyKnowledge](https://github.com/DennisRas/WeeklyKnowledge), the same source as the quest IDs.

## Debug isolation

If something errors and you are not sure which addon did it, `/ls debug` turns off every
non-Blizzard addon except Lodestar, then reloads. Reproduce the problem. If it still happens,
it is Lodestar (or the client). If it does not, another addon was involved.

`/ls debug` again, or `/ls debug off`, restores the addons that were on. The restore list
survives `/ls reset`. Isolation is per character, and it will not run in combat.

## Releases

CurseForge packages from git tags and sets the file type from the tag name:

- `v1.13.0-alpha` — alpha (`alpha` anywhere in the tag)
- `v1.12.1-beta` — beta (`beta` anywhere in the tag)
- `v1.13.0` — release (no `alpha` or `beta` in the tag)

The word `alpha` or `beta` in the tag is what CurseForge looks for. A tag with neither is a
release. Untagged commits are only packaged if the webhook is set to package every commit,
and those files are always marked alpha.

## Development

`.dev/run.py` loads every file into a stubbed client, fires the real login events and clicks
through the UI to check behaviour without launching the game. It needs `lupa`.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
