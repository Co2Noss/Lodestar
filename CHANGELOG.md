# 1.0.0

First official (non-beta) GitHub and CurseForge release.

- Compact mode shows one row when a single goal is on and two when more are. Height
  follows that, so the window contracts and expands instead of always listing three.
- A Great Vault row only recommends the next slot that still needs work. Later empty
  slots stay quiet until the earlier one is filled.

# 1.17.1

- Gold making now ranks Midnight herbs, ore, skins and cloth, Khaz Algar skins and cloth,
  and older cloth anyone can loot. Same price addons, same quiet if none is loaded.
- Midnight professions now track all eight world knowledge treasures plus the vendor books,
  from the WeeklyKnowledge data set. Unspent knowledge, weeklies, drops and the live
  specialization tree were already ranked; recipe checklists stay in the profession window.

# 1.17.0

- If last week's Great Vault is still sitting there after Tuesday reset, Today tells you
  to claim it and pick your loot.
- New Gold making goal. Gathering you have trained and a few pet farms are ranked from
  TSM, Auctionator or RECrystallize prices. Settings → Goals picks the source; Auto uses
  whichever of those is loaded. Nothing is ranked until a price addon is actually there.

# 1.16.0

- Settings → Reputation now draws a border around the expansion strip and the faction
  list, so those read as sub-options of Reputation rather than a second row of tabs.
- Clicking a profession opens that profession's window. Professions with a knowledge
  tree also get a Specializations button, and the card shows how many points are
  already spent.
- A Bountiful Delve stays off the plan once the World Vault is finished, you have no
  Restored Coffer Keys, you cannot make another key from shards, and this week's
  T11 Gilded Stashes are done.

# 1.15.0

- Recommendations now rank as High, Medium or Low, instead of Now, Anytime and This Week.
- Cooking, Fishing and Archaeology sit on the Professions page with the two primaries.
  They have no knowledge tree, so the page shows skill, and Today recommends leveling them
  until they are at the cap.

# 1.14.0

- Escape closes the main window. Compact mode stays up.
- Reputation is now the player's live factions, grouped by expansion and category, not a
  single placeholder. Settings has a Reputation tab to turn on the expansions, categories
  or individual factions you care about, each expansion on its own tab. Finished standings stay off the plan, and nothing
  is ranked until you pick something. If you pick factions while the Reputation goal is off,
  Settings says so and offers to turn it on.

# 1.13.0

- The Mounts goal now ranks weekly raid and world-boss farms you do not already have.
  Icecrown Citadel is the pattern: if you lack Invincible and 25 Heroic is still open this
  week, it is on the plan; if you already own the mount, or already killed the Lich King
  this lockout, Lodestar stays quiet. Dungeon farms with no weekly lockout still appear,
  but as ANYTIME.

# 1.12.1

- The window and compact mode now sit above nameplates, so Ellesmere's personal plate
  no longer draws through the cards.

# 1.12.0

- Today, Great Vault and Professions now use the same tab strip as Settings, so moving
  between groups is a click rather than a scroll.
- Today tabs are the plan's categories (Great Vault, Professions, Reputation, Solo content,
  Questing). Only categories with work appear, their order stays put as scores change, and
  the collapse control is gone because the strip replaced it.
- Great Vault is Raid, Dungeons and World. Professions is one tab per trained profession.
  The last tab on each page is remembered.

# 1.11.0

- Settings is now tabbed. Goals, Appearance, Compact and Layout each have their own pane, so
  finding the next setting is a click rather than a scroll. The tab you were last on is saved.
- The color labelled Window is now Background, so it is not confused with the Layout tab.

# 1.10.0

- The Blizzard theme now uses the client's own frame art, the modern panel style Dragonflight
  introduced, instead of a hand-drawn blue-grey approximation. The window's flat backdrop and
  one pixel border step aside for it, the title bar stops drawing its own fill the way
  Blizzard's windows do, and the content moves inward to sit inside the thicker border.
- Its colours now come from the client itself: the gold of `NORMAL_FONT_COLOR`, white body
  text, and Blizzard's own red and grey for warnings and muted text.
- If a client offers no panel art, the theme falls back to a flat frame in the same colours
  rather than rendering borderless, and Settings says which of the two you are looking at.
- Every colour the interface uses can now be changed. Settings lists accent, text, window,
  panels, cards, borders, warnings and muted text, and clicking one opens Blizzard's colour
  picker with opacity.
- Chosen colours override the theme, including ElvUI's live media, and survive switching
  themes. Changed rows are marked, and one button resets them all.
- Removed the theme debug output: changing a theme no longer prints to chat, and the sidebar
  no longer carries a "Theme: X" readout. `/ls theme` still lists the options.

# 1.9.0

- Lodestar now asks what you care about at your first login instead of guessing. The window
  opens on a welcome page listing every goal, and says there that Settings can change the
  answer later.
- Every goal now starts off. Previously endgame, solo content and professions were on and
  mounts, reputation and questing were off, which silently hid recommendations from players who
  never chose those defaults.
- Nothing is ranked until at least one goal is on, so the welcome page asks for a choice rather
  than letting you continue into an empty plan. "I care about all of it" turns on everything at
  once.
- An empty Today page now explains that every goal is off and links back to goal picking,
  rather than only pointing at Settings.
- Existing installs are untouched: goals you have already chosen count as an answer, so the
  welcome page never interrupts an upgrade.
- Added `.dev/run.py`, a headless harness that loads the addon into a stubbed client, fires the
  real login events and clicks through the UI.

# 1.8.0

- Removed the time budget and its slider from both the Today page and Settings. Lodestar no
  longer asks how long you have and then hides whatever does not fit; it ranks everything and
  lets you choose.
- Today now groups recommendations into collapsible categories: Great Vault, Professions,
  Reputation, Solo content, Questing. Categories are ordered by the best thing inside them, and
  collapsing one is how you filter out what you do not care about. Collapsed state is saved.
- A collapsed category still shows its count, total time and the urgency of its best entry, so
  collapsing never hides that there is work in there. "Collapse all" and "Expand all" flip
  everything at once.
- Recommendation cards now show urgency and score alongside the time estimate, since urgency is
  what the time budget used to imply.
- Activities can declare their own urgency. Renown is ANYTIME because it never expires, rather
  than being called urgent for scoring well.
- Compact mode hides itself while the full window is open and returns when it closes. Both
  showed the same plan, so there was no reason for both to be on screen.
- Scoring no longer adjusts for a session length, so scores now reflect goals and tracking only.

# 1.7.0

- New compact mode: a small always-on window showing the next three things to do, each with its
  urgency, estimated time and score. Toggle it in Settings, with `/ls compact`, or by right-clicking
  the minimap button.
- Single recommendation mode trims it to the highest-scoring activity alone.
- Click an entry for its details page, double click anywhere for the full window.
- Collapses to its title bar when you enter combat and restores itself when you leave. A manual
  collapse is not undone by combat ending.
- Position and width are saved. Height follows the number of recommendations, so nothing is clipped
  and there is no dead space.
- Urgency is based on when something expires rather than only its score: one-time treasures read
  ANYTIME however valuable they are, while unspent knowledge reads NOW because it costs nothing.
- Added `warn` and `muted` colours to every palette, including the one built from ElvUI's media, so
  compact mode is themed like the rest of the addon.

# 1.6.0

- Profession knowledge is now real data instead of a placeholder. Lodestar ships every knowledge
  source for Midnight and The War Within: treatises, weekly quests, world drops from gathering and
  disenchanting, and one-time treasures. 152 quest IDs across 22 profession skill lines, checked
  against the community data set maintained by
  [WeeklyKnowledge](https://github.com/DennisRas/WeeklyKnowledge).
- The Professions page breaks each profession into weekly quests, weekly drops and treasures, with
  the knowledge each is still worth and the specific items still outstanding.
- Catch-up knowledge reports the gates it is waiting on. For gathering and Enchanting it unlocks
  once the week's fixed sources are exhausted, so the page shows how close each gate is instead of
  a point total.
- Alternative quests count once. A trainer offering three quests that reward one is 1 task, not 3.
- Weekly quests, world drops and treasures each get their own recommendation, since turning in a
  quest and farming drops are not the same ask. Details pages list exactly what is left.
- The close button was drawing in an unthemed font colour, which made it nearly invisible against
  ElvUI's backdrop. It now takes the theme's text colour, is larger, and turns red on hover.

# 1.5.1

- Professions now lists only the professions this character has actually trained. The client's
  profession list covers every profession in the game, so it is filtered against the two primary
  professions in your spellbook.
- Added a current-expansion filter on the Professions page, on by default, with older skill lines
  one click away.
- Current-expansion skill level now comes from the spellbook, so it is correct before you open a
  profession window.
- Fixed delve and dungeon upgrade counts. The weekly run list is read with the fields the client
  actually returns (`difficulty` and `numPoints` for world activities, keystone history for
  dungeons), so a Tier 7 slot backed by seven Tier 11 runs now correctly asks for one more run
  instead of miscounting.
- Vault slots show the top runs that produced the current tier, matching the game's own tooltip.
- Fixed the missing logo. Textures are now TGA; the previous PNG path lacked the extension the
  client requires, so nothing loaded.

# 1.5.0

Roadmap releases 1.2 through 1.5 in one pass.

## Great Vault intelligence (1.2)
- Slots report real difficulty and tier names instead of raw difficulty IDs.
- Upgrade effort is counted from banked boss kills and runs, so recommendations state how many are left.
- Fixed delve and dungeon slots being called maxed when a higher tier was still available. A slot is
  maxed only at the known tier cap or above your own best run.
- `raidString` is formatted the way the client formats it, with no placeholder patching.

## ElvUI integration (1.3)
- With ElvUI loaded, Lodestar uses ElvUI's backdrop colour, border colour, status bar texture and font.
- Settings states whether native ElvUI media is in use.

## Activity details (1.4)
- Every recommendation opens a details page: current state, potential, effort, next reward,
  estimated time, why it matters, and what it unlocks.
- Live renown rank and progress are shown for reputation activities.
- Track pins an activity so it outranks other suggestions.

## Warband planner (1.5)
- New Warband page totals characters, vault upgrades waiting, unspent knowledge and renown tracks.
- Per-character rows with vault status, knowledge and mount counts, plus a way to forget a character.

## Professions
- New Professions page with skill, unspent knowledge and knowledge remaining to finish the trees.
- Weekly tasks, treasures and catch-up currency are reported from registered data only, and are
  labelled as untracked rather than complete when no data exists for the build.

## Interface
- Theme picker is a working dropdown; the old version was never anchored and did not appear.
- Time budget is a slider from 1 second to 24 hours on a logarithmic curve.
- The window is always resizable; the on/off toggle is gone.
- Scrollbars on Great Vault, Professions, Warband and Settings.
- Addon logo in the header and on the minimap button.

# 1.1.1
- Fixed theme command routing.
- Fixed raw `%d` Great Vault descriptions.
- Rebuilt the UI with a modern flat design.
- Added immediate theme refresh and active-theme display.
