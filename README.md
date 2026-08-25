# Lodestar 1.12.0

Lodestar answers one question: what is the best use of your next hour in World of Warcraft?

## First login

Lodestar asks what you care about before it recommends anything. Every goal starts off, the
window opens on the welcome page at your first login, and nothing is ranked until you pick at
least one goal. It says there and then that Settings can change your answer at any time.

The reason it asks instead of guessing: a goal that is off silently removes recommendations,
and a player who never chose those defaults has no way to know what is missing.

Existing installs are left alone. Goals you already chose count as an answer, so the welcome
page never interrupts an upgrade.

## Pages

- **Today** — recommendations matching your goals, ranked best first and split into tabs by where the work happens. The last tab you were on is remembered.
- **Great Vault** — Raid, Dungeons and World each have their own tab, with every slot, its current reward quality, and what would improve it.
- **Professions** — one tab per trained profession: skill, unspent knowledge, weekly quests, drops, treasures and catch-up.
- **Warband** — every character Lodestar has seen, with vault and knowledge status.
- **Settings** — split into Goals, Appearance, Compact and Layout, so each group is a click rather than a scroll. The last tab you were on is remembered.

## Ranking and categories

Recommendations are scored against the goals you chose on first login, which Settings can
change at any time, then grouped by where the work happens: Great Vault, Professions,
Reputation, Solo content, Questing. Today, Great Vault, Professions and Settings each use
the same tab strip, so moving between groups is a click rather than a scroll. Tab order on
Today is stable; the work inside a tab is still ranked best first. The last tab on each
page is remembered.

Every card shows its urgency, estimated time and score. Urgency answers "when does this stop
being available" rather than "how good is it": a one-time treasure reads ANYTIME no matter how
much knowledge it carries, unspent knowledge reads NOW because spending it is free, and
renown reads ANYTIME because it never expires. Activities can state their own urgency, and
anything that does not is derived from its type and score.

There is no time budget. Lodestar ranks and groups everything instead of asking how long you
have and hiding whatever does not fit.

## Great Vault accuracy

Slots report a real difficulty or tier, never a raw difficulty ID. Upgrade effort is counted
from the runs and boss kills you have actually banked this week, so "complete 4 delves at
Tier 8 or higher" reflects what is left rather than a guess.

A slot is only called maxed when it reaches the tier cap in `LS.tierCaps` or the highest
tier you have personally cleared. Edit that table when a patch changes the cap.

## Professions and knowledge

Only professions this character has trained are listed, filtered to the current expansion by
default. Skill level, unspent knowledge and remaining tree cost come from live APIs and are
always accurate.

Knowledge is split by what it actually asks of you:

- **Weekly quests** — treatises and trainer or Consortium quests. Where a trainer offers several
  quests but only rewards one, that counts as a single task.
- **Weekly drops** — knowledge that drops while gathering, mining, skinning or disenchanting.
- **Treasures** — one-time world pickups, which never expire.
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

## Compact mode

A small window that sits on your screen with just the next three things to do, each showing
its urgency, estimated time and score. Turn it on in Settings, with `/ls compact`, or by
right-clicking the minimap button.

- Click an entry to open its details page. Double click anywhere to open the full window.
- Single recommendation mode narrows it to the highest-scoring activity.
- It hides itself while the full window is open, since both show the same plan, and comes
  back when you close it.
- It collapses to its title bar in combat and comes back when you leave. If you collapsed it
  yourself, combat ending leaves it collapsed.
- Drag to move, drag the right edge to set the width. Both are saved. Height follows the
  number of recommendations rather than being dragged, so entries are never clipped.

Urgency answers "when does this stop being available", not "how good is it". A one-time
treasure reads ANYTIME no matter how much knowledge it carries, because it waits forever.
Unspent knowledge reads NOW, because spending it is free.

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
position are saved.

## Commands

- `/ls`
- `/ls theme auto` (also blizzard, elvui, ellesmere, minimal)
- `/ls compact`
- `/ls compact single`
- `/ls reset`

## Development

`.dev/run.py` loads every file into a stubbed client, fires the real login events and clicks
through the UI to check behaviour without launching the game. It needs `lupa`.
