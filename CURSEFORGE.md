Paste the **Summary** line into CurseForge’s short summary field. Paste everything under **Description** into the project Description editor with Markdown mode on.

## Summary

```
A decision engine for World of Warcraft. Blizzard shows you everything you can do. Lodestar tells you what is worth doing.
```

## Description

```md
# Lodestar

**Find what matters. Ignore the rest.**

Lodestar is a decision engine for World of Warcraft. It looks at your Great Vault, professions, reputations, and the goals you actually care about, then ranks what is worth doing next. It is not a checklist of five hundred world quests.

**CurseForge:** [Lodestar Guide](https://www.curseforge.com/wow/addons/lodestar-guide)
**GitHub:** [Co2Noss/Lodestar](https://github.com/Co2Noss/Lodestar)
**Latest release:** [v1.3.0](https://github.com/Co2Noss/Lodestar/releases/tag/v1.3.0)
**Discord:** [Lodestar Guide](https://discord.gg/a7hrHavcwq)
**PayPal:** [paypal.me/Co2Noss](http://paypal.me/Co2Noss)

---

## What it does

On first login Lodestar asks what you care about: Great Vault and endgame, solo content, professions, mounts, reputation, questing, or gold making. Nothing is assumed. A goal that is off is hidden on purpose, so it will not silently drop recommendations you never chose to ignore. You can change this later in Settings.

Lodestar works on its own. Optional addons unlock extra behaviour if they are loaded:

- **TradeSkillMaster, Auctionator, or RECrystallize** — gold prices. Without one, gold making stays quiet.
- **TomTom** — multiple waypoints and a closest-arrow. Without it, Lodestar uses the client's single map pin.
- **HandyNotes** plus a notes pack — nearby **rares** those packs mark. [HandyNotes](https://www.curseforge.com/wow/addons/handynotes) by itself has no coordinates; packs such as [Midnight](https://www.curseforge.com/wow/addons/handynotes-midnight) and [Silvermoon](https://www.curseforge.com/wow/addons/handynotes-silvermoon) (and many others) supply the pins. Lodestar ranks rares, not treasures or other map marks. Known rewards stay hidden if the pack hid them. Without a pack, Lodestar stays quiet about rares.
- **ElvUI** — the ElvUI theme reads ElvUI's live backdrop, border, texture, and font.

From there it builds a plan. The left menu is workspaces (Dashboard, planning, tracking, account), not a second copy of Today's tabs:

- **Today's Plan** — ranked recommendations, split into tabs (Great Vault, Professions, Reputation, Gold, Solo content, Questing). Only categories with work appear. The tab you were last on is remembered. Bountiful delves are named from the map when the client marks them. Questing ranks the current campaign and quests already in the log; if those are empty it asks you to check the map.
- **Weekly Plan** / **Long-Term Goals** — the same cards, split by whether they reset this week or wait.
- **Progress** — this character's Great Vault and professions. Raid, Dungeons, and World each have their own tab. Every slot shows current reward quality, whether it can still be improved, and how much work that takes. A delve slot is only called maxed when it is actually at the cap. If last week's chest is unclaimed, Today's Plan tells you to pick your loot. Professions keep one tab per trained profession; Open (or a click on the page below the tabs) opens that profession.
- **Gold making** — gathering you have trained, cloth from humanoids, and a few pet farms, priced from TSM, Auctionator, or RECrystallize. Settings → Goals picks the source.
- **Warband** — every character Lodestar has seen on the account, with vault and knowledge status.
- **Settings** — Goals, Appearance, Compact, and Layout on their own tabs.

Each recommendation shows **priority** and **score**. Priority is High, Medium, or Low. Unspent knowledge and weekly lockouts are High. Gathering and unfinished secondaries are Medium. Treasures, HandyNotes rares, catch-up, dungeon mount farms, and unfinished reputations are Low because they wait. Score still decides the order.

There is no time-budget slider. Lodestar ranks everything that matches your goals instead of hiding whatever does not fit a session length.

---

## Compact mode

A small always-on window with the next thing to do, or two when more goals are on.

- Toggle it in Settings, with `/ls compact`, or by right-clicking the minimap button.
- Click an entry for details. Double-click to open the full window.
- Hides while the main window is open. Collapses to the title bar in combat.
- Position and width are saved.

---

## Looks

- **Blizzard** uses the modern panel art from Dragonflight and the client’s own font colors.
- **ElvUI** reads ElvUI’s backdrop, border, texture, and font when ElvUI is loaded.
- **Ellesmere** and **Minimal** are standalone palettes.
- Every color (accent, text, background, panels, cards, borders, warnings, muted text) can be changed in Settings → Appearance. Your colors survive switching themes.

The window is draggable and resizable. Size and position are saved.

---

## Commands

| Command | What it does |
| --- | --- |
| `/ls` | Open or close Lodestar |
| `/ls compact` | Toggle compact mode |
| `/ls compact single` | Toggle single-recommendation compact mode |
| `/ls theme auto` | Follow ElvUI / Ellesmere when loaded (`blizzard`, `elvui`, `ellesmere`, `minimal` also work) |
| `/ls debug` | Disable every other addon and reload, to see if an error is Lodestar |
| `/ls debug off` | Restore the addons `/ls debug` turned off |
| `/ls reset` | Wipe saved settings and reload |

Treasure cards with a known location have a **Waypoint** button. TomTom pins every remaining pickup; without it, Lodestar uses the client's single map pin. HandyNotes rares get the same button; treasures and other map marks stay off that card. Bountiful delves pin from the map POIs when the client names them. Midnight gathering farms have a **Map** button for the zone circuit.

Left-click the minimap button for the full window. Right-click for compact mode.

---

## What it is not

- Not a replacement for your quest tracker.
- Not a list of everything available in the game.
- Profession catch-up from Patron Orders cannot be counted from the client, so Lodestar describes it instead of inventing a number.

---

## Feedback

File issues on [GitHub](https://github.com/Co2Noss/Lodestar/issues) or talk to us on [Discord](https://discord.gg/a7hrHavcwq). Include your class/spec, the theme you use (Blizzard, ElvUI, or other), and what you expected versus what happened. If you are not sure Lodestar is the addon erroring, `/ls debug` isolates it.
```
