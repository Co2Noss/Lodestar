# Lodestar Support bot

Discord bot for the [Lodestar Guide](https://discord.gg/a7hrHavcwq) server. It builds the support layout, answers FAQs from how the addon actually works, and opens private tickets.

## What it does

- **`/setup`** — creates roles, categories, and channels (idempotent; `#git-commits` is reused). Posts welcome, rules, FAQ, and the ticket panel.
- **`/faq`** — install, goals, gold, rares, vault, debug, themes, and the rest of the support answers.
- **`/ticket` / `#get-help` button** — private ticket with class/spec, theme, version, and expected vs actual.
- **`/close`** — closes a ticket and files a transcript in `#ticket-logs`.
- **`/mod`** — warn, timeout, kick, ban, unban, purge, warnings. Right-click a user for **Timeout 10m** or **Warn**; right-click a message for **Delete and warn**.
- Automod deletes invite ads, mass mentions, and message spam, then warns. Repeat strikes time the user out. Logged in `#mod-log`.
- **Verification** — `#welcome` button **I have read the rules** grants **Member** and removes **Unverified**, which hides `#welcome` and `#silence-enforced`. The join ping in `#welcome` is deleted, and a welcome is posted in `#general`. Unverified people only see welcome, rules, and the honeypot; `#rules` stays visible after they pass. Discord verification level is High (10 minutes in the server). Accounts younger than 1 hour cannot verify.
- **`#silence-enforced`** — honeypot. Any message is a softban (ban + unban, which kicks and wipes a day of messages). Kick count is on the pinned panel.
- **GitHub feeds** — the bot keeps Discord webhooks named **Lodestar GitHub** (compass icon) in `#git-commits`, `#github-releases`, and `#github-issues`, then posts new activity from `Co2Noss/Lodestar` about once a minute. `#github-issues` is issues only (opened or updated), not pull requests. First poll only sets a watermark so old history is not dumped.
- **`/help`** — short map of the server.

Roles: **Unverified**, **Member**, **Developer**, **Moderator**, **Support**, **Bot**. New joins get Unverified until they pass the rules. Staff Discord IDs are listed in `.env` as `DEVELOPER_USER_IDS`. Bots get Bot.

Custom emojis live in `emojis/` and upload on bot start: `:lodestar:` (the compass), plus WoW-style `:gold:` `:vault:` `:profession:` `:quest:` `:pvp:` `:flask:` `:bag:`. They are original icons, not Blizzard art.

First login also runs setup if `#get-help` is missing, so inviting the bot with Administrator is enough.

## Run it

**Secrets never go in `src/config.js`.** Copy `.env.example` to `.env` and fill in your bot token, application ID, guild ID, and staff user IDs. Without a complete `.env` the process exits immediately. See [SECURITY.md](./SECURITY.md).

1. Discord Developer Portal → your application → **Bot**
   - Enable **SERVER MEMBERS INTENT** and **MESSAGE CONTENT INTENT**
   - Copy the token into `.env` as `DISCORD_TOKEN`
2. Invite the bot to **your** support server with Administrator (or Manage Channels + Manage Roles + Send Messages + Embed Links + Manage Messages + Use Application Commands). Include the `applications.commands` scope.
3. Set `DISCORD_GUILD_ID` in `.env` to that server's ID. The bot **leaves any other server** it is added to.
4. From this folder:

```bash
cp .env.example .env
# fill DISCORD_TOKEN, DISCORD_CLIENT_ID, DISCORD_GUILD_ID, DEVELOPER_USER_IDS
npm install
npm start
```

5. Drag the bot role above Developer, Moderator, Support, and Bot in Server Settings → Roles.
6. Slash commands appear within a few seconds. Rebuild later with `/setup`.

If this repository was ever public with old defaults in `config.js`, **reset the bot token** in the Developer Portal and update `.env`.

The process must stay running. When it stops, the bot goes offline and tickets stop working. A VPS, Railway, Fly.io, or a home machine is enough. `Dockerfile` is in this folder if you prefer a container.

## CurseForge

This folder is listed in the repo `.pkgmeta` ignore list so it is not packed into the WoW addon zip.
