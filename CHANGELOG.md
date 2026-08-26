# 1.5.1

- Settings → Reputation no longer paints a full-page panel over the faction list,
  so Rank all and the factions stay readable.

# 1.5.0

- Edit dashboard shows **settings only** on a tile — live Honor, gold, house
  favor, dungeon icons, and the rest stay off until Done editing. PvP lists
  every bracket (including Blitz) so the Honor line cannot clip them. Tiles
  that needed options now have them (Overview totals, Jump shortcuts,
  profession icons/Open, Great Vault and Warband buttons, Tracked Progress,
  currency track list, token/warband-gold format, item-level slots/flags/bags,
  housing Dashboard/Teleport, calendar weeks, guild emblem, journey bars,
  Mythic+ score/dungeons). Weekly reset, gold farms, and rares say they have
  nothing extra to set.
- Housing **Teleport** calls `C_Housing.TeleportHome` from the click itself.
  Wrapping that protected API in `pcall` tainted the hardware event and the
  client blocked it (`ADDON_ACTION_FORBIDDEN`).
- Item Level flags this expansion's enchants and sockets from the item link:
  helm (enchant and socket), shoulder (enchant), wrist (socket only), back
  (neither). Rings take both; a gemmed ring is not flagged for sockets.
- Click a dashboard tile that opens a client window again to close it:
  character, currencies, calendar, guild, Mythic+, Great Vault, Housing
  Dashboard, Journeys, and the profession window.
- Scrolling the dashboard (including in edit mode) stays put when the page
  redraws instead of jumping back to the top.
- Lodestar sits on HIGH so the client's calendar, Mythic+ Dungeons, Great Vault,
  Housing Dashboard, and profession window can raise in front instead of opening
  behind the window.
- The Professions tile shows icons for your two primaries; click one to open
  that profession in front of Lodestar. Open still goes to Lodestar's profession
  page.
- Edit dashboard reuses the same canvas instead of stacking a second copy of
  the tiles on top of the last redraw.
- The Guild tile centers the emblem under the guild name.
- Delver's Journey, Preyhunter's Journey, and Housing paint a bar toward the
  next rank or house level from the client.
- A full dashboard canvas grows down (to 36 rows) instead of ignoring Add.
  If it cannot grow, the new tile uses the leftover hole, or chat says the
  canvas is full. Edit mode lists each addable tile's size in cells.
- Dashboard tiles clip instead of wrapping over themselves when the window is
  shrunk. Next stacks Details / Done / Ignore under the card copy; Currencies keep
  the name on the left and the amount on the right.
- Click the **Mythic+** tile (or a dungeon on it) to open the client's Mythic+
  Dungeons tab, the same way Great Vault opens the chest.
- The **tip tour** walks to the feature and highlights it instead of sitting on its own
  page. Skip hides the rest; Next is the next tip.
- Settings → **Changelog** lists the last five versions.
- Settings → Optional Addons lists every addon Lodestar talks to as **Loaded** (green) or **Not loaded** (grey).
- Letter gold on WoW Token and the gold tile colours gold, silver, and copper separately.
- Settings → Goals includes **Housing**. A missing house, unfinished neighborhood
  initiatives, and weekly housing quests already in the log (Housewarming and the
  like) rank from `C_Housing` / `C_NeighborhoodInitiative` / the quest log while
  that goal is on. Lodestar does not invent plots or housing quest IDs. A **Housing**
  dashboard tile shows house level and favor the client reports, opens the client's
  Housing Dashboard, and teleports with `C_Housing.TeleportHome` when a house GUID
  exists.
- Settings → Goals includes **PvP**. Weekly Conquest ranks from
  `C_WeeklyRewards.GetConquestWeeklyProgress` while that goal is on and the week is
  unfinished. Honor and rated scores live on a dashboard tile, not as invented queues.
- Gold prices, waypoints, and HandyNotes notes moved from Goals onto
  **Settings → Optional Addons**.
- Dashboard tiles: **Mythic+** (season score plus this season's dungeon keys from the
  client's mythic rating, coloured by Raider.IO when that addon is loaded), **Warband
  Gold** (characters Lodestar has seen, or TSM's account log when TSM is loaded),
  **Currencies** (this expansion by default; edit mode picks what to track; names use
  the client's rarity colour), **PvP** (honor plus seasonal ratings), and **Item Level**
  (equipped average and best-in-bags from the client, rarity-coloured; each slot
  shows its item level, a red border when that piece is missing an enchant, and a
  yellow caution when the client reports an empty gem slot. Missing flags are listed
  beside the gear so two on one piece never overlap). **Calendar** (this week and next
  from `C_Calendar`, including guild events and invites; click opens the calendar),
  **Guild** (logo plus online / total; click opens Communities), **Delver's Journey**
  and **Preyhunter's Journey** (this season's rank from the client; click opens
  Journeys). WoW Token and
  gold tiles show gold, silver, and copper. Tiles fill the chrome they sit in. Hover a
  tile for a tooltip: Mythic+ uses your player tooltip (`RaiderIO.ShowProfile` or
  `SetUnit("player")`, refreshed on shift), currencies use `SetCurrencyByID` like the
  currency tab.
- Warband lists a **Track** control on each alt when Lodestar has seen more than one
  character. Untracking leaves that snapshot in place but drops it from totals and
  warband gold. Forget still removes it.
- The ElvUI theme's default border is a lighter grey. ElvUI's live border is used when
  it is actually visible; a near-black default is not.
- Themes include **GW2 UI** and **RealUI**. Auto follows GW2 UI, RealUI / Aurora, ElvUI,
  or EllesmereUI when loaded. Live colours come from `GW2_ADDON` and `Aurora.Color`
  when those addons expose them.

# 1.4.1

- Below the expansion cap (90 in Midnight, or `GetMaxLevelForPlayerExpansion` when the
  client has it) Great Vault and bountiful delves stay quiet. The plan is to level and
  enjoy the game; professions still rank if that goal is on.

# 1.4.0

- Settings → Goals includes Prey hunts. Completing a hunt banks World Vault progress and
  hunt gear. An active hunt comes from `C_QuestLog.GetActivePreyQuest`. Quests the client
  marks important (Prey unlocks, Voidcores, and the rest) rank with campaign priority.
- Picking up a dashboard widget lifts it, leaves a drop ghost, and outlines empty rooms
  with a plus where that tile can land. Widget options such as
  WoW Token coin icons, letters, colour, thousands separators, and bar vs line charts only
  appear in edit mode. Compact up packs tiles to the top; widgets cannot overlap.
- Dashboard widgets sit on a 12 × 18 canvas on that tab only. Default tiles start at
  half width, the same size as WoW Token and the other addable widgets. Drag to move;
  drag an edge or corner to resize horizontally or vertically. Edit dashboard to add or
  remove tiles. Built-in tiles include the plan snapshot, Great Vault, tracked work,
  professions, WoW Token (the client's market price), weekly reset, warband, gold (when a
  price addon is loaded), and HandyNotes rares. Other addons can register their own with
  `Lodestar:RegisterWidget`.
- The left menu collapses to icons. Hover an icon for Dashboard, Today's Plan, and the
  rest of the workspaces.
- Compact mode and Progress list activities you tracked, ranked by score. Compact stays
  empty until something is tracked.
- Professions live on Dashboard. Great Vault opens from Dashboard; Progress is the tracked list.
- Dashboard and Warband unspent knowledge only count the current expansion, so leftover
  Khaz Algar (or older) points no longer inflate the Dashboard.

- Bountiful delves on portal continents (Harandar, Voidstorm) are picked up even
  when you are standing on Quel'Thalas. Those maps are siblings of Midnight, not
  children of it.

- Settings → Goals: choose Auto, TomTom, or the client's map pin for waypoints. Auto still
  uses TomTom when it is loaded; Blizzard waypoint ignores it.
- Dashboard opens the client's Great Vault. Hover and each vault slot show named keys and
  reward item levels the client knows. Champion/Hero ranks stay in Great Vault Key Info
  inside the client's vault window.

# 1.3.0

- The left menu is workspaces, not a second copy of Today's tabs: Dashboard, Today's Plan,
  Weekly Plan, Long-Term Goals, Progress, Ignored, Completed, Warband and Settings. Great Vault
  and Professions live under Progress.
- Bountiful delves are named from the map when the client marks them. If it has not named them
  yet, the card still asks you to run one and to check the map. The old quiet-when-done rule
  is unchanged.
- Questing ranks the current campaign (including catch-up when a chapter is stalled) and a few
  quests already in the log. World quests stay off that card. If the log is empty and no
  campaign work is waiting, Lodestar asks you to check the map.
- Settings → Reputation uses denser rows: Rank all is the header, groups are smaller, and
  individual factions are compact.

# 1.2.0

- Profession tabs only switch the card. The trade-skill window opens from the Open
  button, Specializations, or a click on the page below the tabs.
- Cards no longer estimate how long something will take. The Today subtitle no longer
  says "Best is High" or "Best is Medium".
- HandyNotes ranks rares only. Treasures and other map marks (trainers, vendors, chests)
  stay off that card, so a capital-city pack is not counted as a rare hunt.

# 1.1.2

- HandyNotes by itself has no coordinates. Solo content ranks pins from a notes pack
  such as Midnight or Silvermoon (and many others). Settings says so if HandyNotes is
  loaded without a pack.

# 1.1.1

- Treasure cards with a known location get a **Waypoint** button. TomTom pins every
  remaining pickup and aims the arrow at the closest; without it, Lodestar uses the
  client's single map pin. Midnight gathering farms get a **Map** button for the zone
  circuit. Treasure coordinates come from WeeklyKnowledge, the same source as the quest IDs.
- With HandyNotes loaded, Solo content ranks rares it is currently showing in your zone.
  Known rewards stay hidden because HandyNotes already hid them. Lodestar does not invent
  spawn data.
- README and CurseForge now list optional addons: TSM / Auctionator / RECrystallize for
  gold prices, TomTom for multiple waypoints, HandyNotes for rares, and ElvUI for live
  theme media.

# 1.0.1

- `/ls debug` turns off every other addon and reloads, so you can tell if an error is
  Lodestar. `/ls debug` again restores them. Isolation is per character, skipped in combat,
  and the restore list survives `/ls reset`.
- README now carries the logo plus CurseForge, GitHub, Discord and PayPal links.

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
