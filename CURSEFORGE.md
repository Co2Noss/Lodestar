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

This is a **beta**. Features work, the UI is usable, and we want feedback. Expect rough edges, and please report them.

**GitHub:** [Co2Noss/Lodestar](https://github.com/Co2Noss/Lodestar)
**Latest beta:** [v1.12.0-beta](https://github.com/Co2Noss/Lodestar/releases/tag/v1.12.0-beta)

---

## What it does

On first login Lodestar asks what you care about: Great Vault and endgame, solo content, professions, mounts, reputation, or questing. Nothing is assumed. A goal that is off is hidden on purpose, so it will not silently drop recommendations you never chose to ignore. You can change this later in Settings.

From there it builds a plan:

- **Today** — ranked recommendations, split into tabs (Great Vault, Professions, Reputation, Solo content, Questing). Only categories with work appear. The tab you were last on is remembered.
- **Great Vault** — Raid, Dungeons, and World each have their own tab. Every slot shows current reward quality, whether it can still be improved, and how much work that takes. A delve slot is only called maxed when it is actually at the cap.
- **Professions** — one tab per trained profession. Skill, unspent knowledge, weekly quests, gathering drops, treasures, and catch-up. Current-expansion only by default.
- **Warband** — every character Lodestar has seen on the account, with vault and knowledge status.
- **Settings** — Goals, Appearance, Compact, and Layout on their own tabs.

Each recommendation shows **urgency**, estimated time, and score. Urgency is “when does this stop being available,” not “how good is it.” Unspent knowledge is NOW (spending it is free). A one-time treasure is ANYTIME (it waits). Renown is ANYTIME (it never expires).

There is no time-budget slider. Lodestar ranks everything that matches your goals instead of hiding whatever does not fit a session length.

---

## Compact mode

A small always-on window with the next three things to do (or just the single best one).

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
| `/ls reset` | Wipe saved settings and reload |

Left-click the minimap button for the full window. Right-click for compact mode.

---

## What it is not

- Not a replacement for your quest tracker.
- Not a list of everything available in the game.
- Not finished. Profession catch-up from Patron Orders cannot be counted from the client, so Lodestar describes it instead of inventing a number.

---

## Feedback

File issues on [GitHub](https://github.com/Co2Noss/Lodestar/issues). Include your class/spec, the theme you use (Blizzard, ElvUI, or other), and what you expected versus what happened.
```
