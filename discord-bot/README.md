# Lodestar Support bot

Discord bot for the [Lodestar Guide](https://discord.gg/a7hrHavcwq) server. It builds the support layout, answers FAQs from how the addon actually works, and opens private tickets.

## What it does

- **`/setup`** — creates roles, categories, and channels (idempotent; `#git-commits` is reused). Posts welcome, rules, FAQ, and the ticket panel.
- **`/faq`** — install, goals, gold, rares, vault, debug, themes, and the rest of the support answers.
- **`/ticket` / `#get-help` button** — private ticket with class/spec, theme, version, and expected vs actual.
- **`/close`** — closes a ticket and files a transcript in `#ticket-logs`.
- **`/help`** — short map of the server.
- Keyword replies in `#general` and the questions forum when a known topic shows up.

First login also runs setup if `#get-help` is missing, so inviting the bot with Administrator is enough.

## Run it

1. Discord Developer Portal → **Lodestar Support** → **Bot**
   - Enable **SERVER MEMBERS INTENT** and **MESSAGE CONTENT INTENT**
   - Copy the token
2. Invite the bot with Administrator (or Manage Channels + Manage Roles + Send Messages + Embed Links + Manage Messages + Use Application Commands). Include the `applications.commands` scope.
3. From this folder:

```bash
cp .env.example .env
# paste DISCORD_TOKEN=
npm install
npm start
```

4. Drag the **Lodestar Support** role above **Support** and **Moderator** in Server Settings → Roles.
5. Slash commands appear within a few seconds. Rebuild later with `/setup`.

The process must stay running. When it stops, the bot goes offline and tickets stop working. A VPS, Railway, Fly.io, or a home machine is enough. `Dockerfile` is in this folder if you prefer a container.

## CurseForge

This folder is listed in the repo `.pkgmeta` ignore list so it is not packed into the WoW addon zip.
